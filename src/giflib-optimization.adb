with Giflib.Errors;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Internal.Pixel_Arithmetic;

package body Giflib.Optimization is
   function Charge_One
     (Object : in out Internal.Work_Budgets.Meter) return Boolean
   is
      Accepted : Boolean;
   begin
      Internal.Work_Budgets.Try_Charge (Object, 1, Accepted);
      return Accepted;
   end Charge_One;

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
      Pixel_Position : Natural;
      Position_Previous : Natural := 0;
      Position_Current : Natural := 0;
      Safe : constant Boolean :=
        Internal.Optimization_Arithmetic.Is_Safe
          (Previous_Control, Current_Control, Palettes_Are_Equivalent);
      Analysis : Frame_Analysis;

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
      for Y in 0 .. Natural (Height) - 1 loop
         for X in 0 .. Natural (Width) - 1 loop
            if not Charge_One (Work) then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     Internal.Resource_Diagnostics.With_Work_Limit
                       (Work, Optimization_Work_Limit)));
            end if;
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
            for Y in Natural (Bounds.Min_Y) .. Natural (Bounds.Max_Y) loop
               for X in Natural (Bounds.Min_X) .. Natural (Bounds.Max_X) loop
                  if not Charge_One (Work) then
                     return Results.Failure
                       (Errors.Make
                          (Errors.Limit_Exceeded,
                           Internal.Resource_Diagnostics.With_Work_Limit
                             (Work, Optimization_Work_Limit)));
                  end if;
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
      Source_Position : Natural;
      Work : Internal.Work_Budgets.Meter
        (Constraints.Max_Optimization_Work);
      Use_Transparency : Boolean :=
        Item.Action = Trim_To_Rectangle
        and then Item.Requires_Transparency
        and then Options.Make_Interior_Unchanged_Transparent;

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
         for Y in Natural (Item.Top) .. Natural (Item.Top) + Natural (Item.Height) - 1 loop
            for X in Natural (Item.Left) .. Natural (Item.Left) + Natural (Item.Width) - 1 loop
               if not Charge_One (Work) then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Limit_Exceeded,
                        Internal.Resource_Diagnostics.With_Work_Limit
                          (Work, Optimization_Work_Limit)));
               end if;
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

      for Y in Natural (Item.Top) .. Natural (Item.Top) + Natural (Item.Height) - 1 loop
         for X in Natural (Item.Left) .. Natural (Item.Left) + Natural (Item.Width) - 1 loop
            if not Charge_One (Work) then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     Internal.Resource_Diagnostics.With_Work_Limit
                       (Work, Optimization_Work_Limit)));
            end if;
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
