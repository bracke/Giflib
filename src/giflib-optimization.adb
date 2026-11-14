with Giflib.Errors;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Internal.Pixel_Arithmetic;

package body Giflib.Optimization is
   type Visit_Action is (Continue_Visit, Stop_Visit);

   function Walk_Rectangle
     (Work : in out Internal.Work_Budgets.Meter;
      Left : Natural;
      Top : Natural;
      Width : Natural;
      Height : Natural;
      Canvas_Width : Image_Width;
      Visit : not null access function
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action)
      return Results.Result
   is
      Accepted : Boolean;
   begin
      for Y in Top .. Top + Height - 1 loop
         for X in Left .. Left + Width - 1 loop
            Internal.Work_Budgets.Try_Charge (Work, 1, Accepted);
            if not Accepted then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     Internal.Resource_Diagnostics.With_Work_Limit
                       (Work, Optimization_Work_Limit)));
            elsif Visit
              (X, Y,
               Natural
                 (Internal.Pixel_Arithmetic.Pixel_Index
                    (X, Y, Canvas_Width))) = Stop_Visit
            then
               return Results.Success;
            end if;
         end loop;
      end loop;
      return Results.Success;
   end Walk_Rectangle;

   function Analyze_Indexed
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean;
      Item : out Frame_Analysis;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      Required : constant Byte_Count := Internal.Geometry_Arithmetic.Area (Width, Height);
      Work : Internal.Work_Budgets.Meter
        (Constraints.Max_Optimization_Work);
      Bounds : Internal.Optimization_Arithmetic.Change_Bounds;
      Has_Unchanged_Interior : Boolean := False;
      Has_Transparent_Index_Conflict : Boolean := False;
      Requires_Transparency : Boolean := False;
      Safe : constant Boolean :=
        Internal.Optimization_Arithmetic.Is_Safe
          (Previous_Control, Current_Control, Palettes_Are_Equivalent);
      Analysis : Frame_Analysis;
      Outcome : Results.Result;

      function Observe_Change
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action is
      begin
         if Previous (Previous'First + Position)
           /= Current (Current'First + Position)
         then
            Bounds := Internal.Optimization_Arithmetic.Include
              (Bounds,
               Internal.Optimization_Arithmetic.Pixel_Coordinate (X),
               Internal.Optimization_Arithmetic.Pixel_Coordinate (Y));
         end if;
         return Continue_Visit;
      end Observe_Change;

      function Observe_Interior
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         if Previous (Previous'First + Position)
           = Current (Current'First + Position)
         then
            Has_Unchanged_Interior := True;
         elsif Current (Current'First + Position)
           = Byte (Options.Transparent_Index)
         then
            Has_Transparent_Index_Conflict := True;
         end if;
         return Continue_Visit;
      end Observe_Interior;

   begin
      if Byte_Count (Previous'Length) /= Required then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required,
                Actual => Byte_Count (Previous'Length), others => <>)));
      elsif Byte_Count (Current'Length) /= Required then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required,
                Actual => Byte_Count (Current'Length), others => <>)));
      end if;
      Outcome := Walk_Rectangle
        (Work, 0, 0, Natural (Width), Natural (Height), Width,
         Observe_Change'Access);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Bounds.Empty then
         if Safe
           and then Internal.Optimization_Arithmetic.Can_Merge_Delay
             (Previous_Control.Delay_CS, Current_Control.Delay_CS)
         then
            Analysis :=
              (Action => Merge_With_Previous,
               Merged_Delay => Internal.Optimization_Arithmetic.Merge_Delay
                 (Previous_Control.Delay_CS, Current_Control.Delay_CS));
         else
            Analysis :=
              (Action => Keep_Full_Frame,
               Full_Width => Width,
               Full_Height => Height);
         end if;
      elsif Safe and then Options.Trim_Unchanged_Border then
         if Options.Make_Interior_Unchanged_Transparent then
            Outcome := Walk_Rectangle
              (Work,
               Natural (Bounds.Min_X), Natural (Bounds.Min_Y),
               Natural (Bounds.Max_X - Bounds.Min_X) + 1,
               Natural (Bounds.Max_Y - Bounds.Min_Y) + 1,
               Width, Observe_Interior'Access);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            Requires_Transparency :=
              Has_Unchanged_Interior and then not Has_Transparent_Index_Conflict;
         end if;
         Analysis :=
           (Action => Trim_To_Rectangle,
            Left => Coordinate (Bounds.Min_X),
            Top => Coordinate (Bounds.Min_Y),
            Width => Internal.Optimization_Arithmetic.Width (Bounds),
            Height => Internal.Optimization_Arithmetic.Height (Bounds),
            Requires_Transparency => Requires_Transparency);
      else
         Analysis :=
           (Action => Keep_Full_Frame,
            Full_Width => Width,
            Full_Height => Height);
      end if;
      if Item'Constrained and then Item.Action /= Analysis.Action then
         return Results.Failure
           (Errors.Make
              (Errors.Output_Variant_Mismatch,
               (Expected => Byte_Count (Optimization_Action'Pos (Item.Action)),
                Actual => Byte_Count (Optimization_Action'Pos (Analysis.Action)),
                others => <>)));
      end if;
      Item := Analysis;
      return Results.Success;
   end Analyze_Indexed;

   function Extract_Indexed_Rectangle
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height;
      Item : Frame_Analysis;
      Output : out Streams.Byte_Array;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      Canvas_Pixels : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Canvas_Width, Canvas_Height);
      Rectangle_Pixels : constant Byte_Count :=
        (if Item.Action = Trim_To_Rectangle
         then Byte_Count (Item.Width) * Byte_Count (Item.Height)
         else 0);
      Output_Position : Natural := 0;
      Work : Internal.Work_Budgets.Meter
        (Constraints.Max_Optimization_Work);
      Use_Transparency : Boolean :=
        Item.Action = Trim_To_Rectangle
        and then Item.Requires_Transparency
        and then Options.Make_Interior_Unchanged_Transparent;
      Outcome : Results.Result;

      function Check_Transparent_Conflict
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         if Previous (Previous'First + Position)
           /= Current (Current'First + Position)
           and then Current (Current'First + Position)
             = Byte (Options.Transparent_Index)
         then
            Use_Transparency := False;
            return Stop_Visit;
         end if;
         return Continue_Visit;
      end Check_Transparent_Conflict;

      function Write_Pixel
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         if Use_Transparency
           and then Previous (Previous'First + Position)
             = Current (Current'First + Position)
         then
            Output (Output'First + Output_Position) :=
              Byte (Options.Transparent_Index);
         else
            Output (Output'First + Output_Position) :=
              Current (Current'First + Position);
         end if;
         Output_Position := Output_Position + 1;
         return Continue_Visit;
      end Write_Pixel;

   begin
      if Item.Action /= Trim_To_Rectangle
        or else Natural (Item.Left) + Natural (Item.Width) > Natural (Canvas_Width)
        or else Natural (Item.Top) + Natural (Item.Height) > Natural (Canvas_Height)
      then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
      elsif Byte_Count (Previous'Length) /= Canvas_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Canvas_Pixels,
                Actual => Byte_Count (Previous'Length), others => <>)));
      elsif Byte_Count (Current'Length) /= Canvas_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Canvas_Pixels,
                Actual => Byte_Count (Current'Length), others => <>)));
      elsif Byte_Count (Output'Length) /= Rectangle_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Rectangle_Pixels,
                Actual => Byte_Count (Output'Length), others => <>)));
      end if;

      --  Item is caller-visible and Options is supplied independently from the
      --  analysis call. Recheck the selected index so either can safely differ
      --  from the values originally analyzed.
      if Use_Transparency then
         Outcome := Walk_Rectangle
           (Work, Natural (Item.Left), Natural (Item.Top),
            Natural (Item.Width), Natural (Item.Height), Canvas_Width,
            Check_Transparent_Conflict'Access);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Walk_Rectangle
        (Work, Natural (Item.Left), Natural (Item.Top),
         Natural (Item.Width), Natural (Item.Height), Canvas_Width,
         Write_Pixel'Access);
   end Extract_Indexed_Rectangle;
end Giflib.Optimization;
