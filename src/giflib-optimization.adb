with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Internal.Pixel_Arithmetic;

package body Giflib.Optimization is
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
      Work : Byte_Count := 0;
      Budget : Internal.Budget_Arithmetic.Charge_Result;
      Bounds : Internal.Optimization_Arithmetic.Change_Bounds;
      Has_Unchanged_Interior : Boolean := False;
      Has_Transparent_Index_Conflict : Boolean := False;
      Pixel_Position : Natural;
      Position_Previous : Natural := 0;
      Position_Current : Natural := 0;
      Safe : constant Boolean :=
        Internal.Optimization_Arithmetic.Is_Safe
          (Previous_Control, Current_Control, Palettes_Are_Equivalent);
   begin
      Item := (others => <>);
      if Byte_Count (Previous'Length) /= Required
        or else Byte_Count (Current'Length) /= Required
      then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Required,
                Actual => Byte_Count'Min
                  (Byte_Count (Previous'Length), Byte_Count (Current'Length)), others => <>)));
      end if;
      for Y in 0 .. Natural (Height) - 1 loop
         for X in 0 .. Natural (Width) - 1 loop
            Budget := Internal.Budget_Arithmetic.Charge
              (Work, Constraints.Max_Optimization_Work, 1);
            if not Budget.Accepted then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     (Expected => Constraints.Max_Optimization_Work,
                      Actual => Budget.Attempted,
                      Limit => Optimization_Work_Limit, others => <>)));
            end if;
            Work := Budget.Total;
            if Previous (Previous'First + Position_Previous)
              /= Current (Current'First + Position_Current)
            then
               Bounds := Internal.Optimization_Arithmetic.Include
                 (Bounds,
                  Internal.Optimization_Arithmetic.Pixel_Coordinate (X),
                  Internal.Optimization_Arithmetic.Pixel_Coordinate (Y));
            end if;
            Position_Previous := Position_Previous + 1;
            Position_Current := Position_Current + 1;
         end loop;
      end loop;
      if Bounds.Empty then
         if Safe
           and then Internal.Optimization_Arithmetic.Can_Merge_Delay
             (Previous_Control.Delay_CS, Current_Control.Delay_CS)
         then
            Item.Action := Merge_With_Previous;
            Item.Merged_Delay := Internal.Optimization_Arithmetic.Merge_Delay
              (Previous_Control.Delay_CS, Current_Control.Delay_CS);
         else
            Item.Action := Keep_Full_Frame;
            Item.Width := Natural (Width);
            Item.Height := Natural (Height);
         end if;
      elsif Safe and then Options.Trim_Unchanged_Border then
         Item.Action := Trim_To_Rectangle;
         Item.Left := Coordinate (Bounds.Min_X);
         Item.Top := Coordinate (Bounds.Min_Y);
         Item.Width := Natural (Internal.Optimization_Arithmetic.Width (Bounds));
         Item.Height := Natural (Internal.Optimization_Arithmetic.Height (Bounds));
         if Options.Make_Interior_Unchanged_Transparent then
            for Y in Natural (Bounds.Min_Y) .. Natural (Bounds.Max_Y) loop
               for X in Natural (Bounds.Min_X) .. Natural (Bounds.Max_X) loop
                  Budget := Internal.Budget_Arithmetic.Charge
                    (Work, Constraints.Max_Optimization_Work, 1);
                  if not Budget.Accepted then
                     return Results.Failure
                       (Errors.Make
                          (Errors.Limit_Exceeded,
                           (Expected => Constraints.Max_Optimization_Work,
                            Actual => Budget.Attempted,
                            Limit => Optimization_Work_Limit,
                            others => <>)));
                  end if;
                  Work := Budget.Total;
                  Pixel_Position := Natural
                    (Internal.Pixel_Arithmetic.Pixel_Index (X, Y, Width));
                  if Previous (Previous'First + Pixel_Position)
                    = Current (Current'First + Pixel_Position)
                  then
                     Has_Unchanged_Interior := True;
                  elsif Current (Current'First + Pixel_Position)
                    = Byte (Options.Transparent_Index)
                  then
                     Has_Transparent_Index_Conflict := True;
                  end if;
               end loop;
            end loop;
            Item.Requires_Transparency :=
              Has_Unchanged_Interior and then not Has_Transparent_Index_Conflict;
         end if;
      else
         Item.Action := Keep_Full_Frame;
         Item.Width := Natural (Width);
         Item.Height := Natural (Height);
      end if;
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
      Rectangle_Pixels : constant Byte_Count := Byte_Count (Item.Width) * Byte_Count (Item.Height);
      Output_Position : Natural := 0;
      Source_Position : Natural;
      Work : Byte_Count := 0;
      Budget : Internal.Budget_Arithmetic.Charge_Result;
      Use_Transparency : Boolean :=
        Item.Requires_Transparency and then Options.Make_Interior_Unchanged_Transparent;
   begin
      if Item.Action /= Trim_To_Rectangle
        or else Item.Width = 0 or else Item.Height = 0
        or else Natural (Item.Left) + Item.Width > Natural (Canvas_Width)
        or else Natural (Item.Top) + Item.Height > Natural (Canvas_Height)
      then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Byte_Count (Previous'Length) /= Canvas_Pixels
        or else Byte_Count (Current'Length) /= Canvas_Pixels
        or else Byte_Count (Output'Length) /= Rectangle_Pixels
      then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Rectangle_Pixels, Actual => Byte_Count (Output'Length), others => <>)));
      end if;

      --  Item is caller-visible and Options is supplied independently from the
      --  analysis call. Recheck the selected index so either can safely differ
      --  from the values originally analyzed.
      if Use_Transparency then
         for Y in Natural (Item.Top) .. Natural (Item.Top) + Item.Height - 1 loop
            for X in Natural (Item.Left) .. Natural (Item.Left) + Item.Width - 1 loop
               Budget := Internal.Budget_Arithmetic.Charge
                 (Work, Constraints.Max_Optimization_Work, 1);
               if not Budget.Accepted then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Limit_Exceeded,
                        (Expected => Constraints.Max_Optimization_Work,
                         Actual => Budget.Attempted,
                         Limit => Optimization_Work_Limit,
                         others => <>)));
               end if;
               Work := Budget.Total;
               Source_Position := Natural
                 (Internal.Pixel_Arithmetic.Pixel_Index (X, Y, Canvas_Width));
               if Previous (Previous'First + Source_Position)
                 /= Current (Current'First + Source_Position)
                 and then Current (Current'First + Source_Position)
                   = Byte (Options.Transparent_Index)
               then
                  Use_Transparency := False;
                  exit;
               end if;
            end loop;
            exit when not Use_Transparency;
         end loop;
      end if;

      for Y in Natural (Item.Top) .. Natural (Item.Top) + Item.Height - 1 loop
         for X in Natural (Item.Left) .. Natural (Item.Left) + Item.Width - 1 loop
            Budget := Internal.Budget_Arithmetic.Charge
              (Work, Constraints.Max_Optimization_Work, 1);
            if not Budget.Accepted then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     (Expected => Constraints.Max_Optimization_Work,
                      Actual => Budget.Attempted,
                      Limit => Optimization_Work_Limit,
                      others => <>)));
            end if;
            Work := Budget.Total;
            Source_Position := Natural
              (Internal.Pixel_Arithmetic.Pixel_Index (X, Y, Canvas_Width));
            if Use_Transparency
              and then Previous (Previous'First + Source_Position)
                = Current (Current'First + Source_Position)
            then
               Output (Output'First + Output_Position) :=
                 Byte (Options.Transparent_Index);
            else
               Output (Output'First + Output_Position) :=
                 Current (Current'First + Source_Position);
            end if;
            Output_Position := Output_Position + 1;
         end loop;
      end loop;
      return Results.Success;
   end Extract_Indexed_Rectangle;
end Giflib.Optimization;
