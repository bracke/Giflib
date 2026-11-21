with Giflib.Errors;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Optimization.Rectangle_Walker;

package body Giflib.Optimization.Analysis is
   package Walker renames Giflib.Optimization.Rectangle_Walker;

   function Analyze_Indexed
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean;
      Item : out Frame_Analysis;
      Options : Optimization_Options;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Required : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Width, Height);
      Work : Internal.Work_Budgets.Meter
        (Constraints.Max_Optimization_Work);
      Bounds : Internal.Optimization_Arithmetic.Change_Bounds;
      Has_Unchanged_Interior : Boolean := False;
      Has_Transparent_Index_Conflict : Boolean := False;
      Requires_Transparency : Boolean := False;
      Safe : constant Boolean :=
        Internal.Optimization_Arithmetic.Is_Safe
          (Previous_Control, Current_Control, Palettes_Are_Equivalent);
      Result_Item : Frame_Analysis;
      Outcome : Results.Result;

      function Observe_Change
        (X : Natural; Y : Natural; Position : Natural)
         return Walker.Visit_Action is
      begin
         if Previous (Previous'First + Position) /=
           Current (Current'First + Position)
         then
            Bounds := Internal.Optimization_Arithmetic.Include
              (Bounds,
               Internal.Optimization_Arithmetic.Pixel_Coordinate (X),
               Internal.Optimization_Arithmetic.Pixel_Coordinate (Y));
         end if;
         return Walker.Continue_Visit;
      end Observe_Change;

      function Observe_Interior
        (X : Natural; Y : Natural; Position : Natural)
         return Walker.Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         if Previous (Previous'First + Position) =
           Current (Current'First + Position)
         then
            Has_Unchanged_Interior := True;
         elsif Current (Current'First + Position) =
           Byte (Options.Transparent_Index)
         then
            Has_Transparent_Index_Conflict := True;
         end if;
         return Walker.Continue_Visit;
      end Observe_Interior;

      function Walk_Changes is new Walker.Walk (Observe_Change);
      function Walk_Interior is new Walker.Walk (Observe_Interior);
   begin
      if Byte_Count (Previous'Length) /= Required then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required,
                Actual => Byte_Count (Previous'Length),
                others => <>)));
      elsif Byte_Count (Current'Length) /= Required then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required,
                Actual => Byte_Count (Current'Length),
                others => <>)));
      end if;
      Outcome := Walk_Changes
        (Work, 0, 0, Natural (Width), Natural (Height), Width);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Bounds.Empty then
         if Safe
           and then Internal.Optimization_Arithmetic.Can_Merge_Delay
             (Previous_Control.Delay_CS, Current_Control.Delay_CS)
         then
            Result_Item :=
              (Action => Merge_With_Previous,
               Merged_Delay => Internal.Optimization_Arithmetic.Merge_Delay
                 (Previous_Control.Delay_CS, Current_Control.Delay_CS));
         else
            Result_Item :=
              (Action => Keep_Full_Frame,
               Full_Width => Width,
               Full_Height => Height);
         end if;
      elsif Safe and then Options.Trim_Unchanged_Border then
         if Options.Make_Interior_Unchanged_Transparent then
            Outcome := Walk_Interior
              (Work,
               Natural (Bounds.Min_X), Natural (Bounds.Min_Y),
               Natural (Bounds.Max_X - Bounds.Min_X) + 1,
               Natural (Bounds.Max_Y - Bounds.Min_Y) + 1,
               Width);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            Requires_Transparency :=
              Has_Unchanged_Interior and then
              not Has_Transparent_Index_Conflict;
         end if;
         Result_Item :=
           (Action => Trim_To_Rectangle,
            Left => Coordinate (Bounds.Min_X),
            Top => Coordinate (Bounds.Min_Y),
            Width => Internal.Optimization_Arithmetic.Width (Bounds),
            Height => Internal.Optimization_Arithmetic.Height (Bounds),
            Requires_Transparency => Requires_Transparency);
      else
         Result_Item :=
           (Action => Keep_Full_Frame,
            Full_Width => Width,
            Full_Height => Height);
      end if;
      if Item'Constrained and then Item.Action /= Result_Item.Action then
         return Results.Failure
           (Errors.Make
              (Errors.Output_Variant_Mismatch,
               (Expected => Byte_Count (Optimization_Action'Pos (Item.Action)),
                Actual =>
                  Byte_Count (Optimization_Action'Pos (Result_Item.Action)),
                others => <>)));
      end if;
      Item := Result_Item;
      return Results.Success;
   end Analyze_Indexed;
end Giflib.Optimization.Analysis;
