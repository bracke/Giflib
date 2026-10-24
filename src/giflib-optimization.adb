with Giflib.Errors;

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
      Required : constant Byte_Count := Byte_Count (Width) * Byte_Count (Height);
      Work : Byte_Count := 0;
      First_Change : Boolean := True;
      Min_X, Max_X, Min_Y, Max_Y : Natural := 0;
      Position_Previous : Natural := Previous'First;
      Position_Current : Natural := Current'First;
      Safe : constant Boolean :=
        Palettes_Are_Equivalent
        and then Previous_Control.Disposal in 0 | 1
        and then Current_Control.Disposal in 0 | 1
        and then not Previous_Control.User_Input
        and then not Current_Control.User_Input
        and then not Previous_Control.Has_Transparency
        and then not Current_Control.Has_Transparency;
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
            if Work >= Constraints.Max_Optimization_Work then
               return Results.Failure
                 (Errors.Make
                    (Errors.Limit_Exceeded,
                     (Expected => Constraints.Max_Optimization_Work, Actual => Work + 1,
                      Limit => Optimization_Work_Limit, others => <>)));
            end if;
            Work := Work + 1;
            if Previous (Position_Previous) /= Current (Position_Current) then
               if First_Change then
                  Min_X := X;
                  Max_X := X;
                  Min_Y := Y;
                  Max_Y := Y;
                  First_Change := False;
               else
                  Min_X := Natural'Min (Min_X, X);
                  Max_X := Natural'Max (Max_X, X);
                  Min_Y := Natural'Min (Min_Y, Y);
                  Max_Y := Natural'Max (Max_Y, Y);
               end if;
            end if;
            Position_Previous := Position_Previous + 1;
            Position_Current := Position_Current + 1;
         end loop;
      end loop;
      if First_Change then
         if Safe
           and then Natural (Previous_Control.Delay_CS) + Natural (Current_Control.Delay_CS) <= 65_535
         then
            Item.Action := Merge_With_Previous;
            Item.Merged_Delay := Delay_Centiseconds
              (Natural (Previous_Control.Delay_CS) + Natural (Current_Control.Delay_CS));
         else
            Item.Action := Keep_Full_Frame;
            Item.Width := Natural (Width);
            Item.Height := Natural (Height);
         end if;
      elsif Safe and then Options.Trim_Unchanged_Border then
         Item.Action := Trim_To_Rectangle;
         Item.Left := Coordinate (Min_X);
         Item.Top := Coordinate (Min_Y);
         Item.Width := Max_X - Min_X + 1;
         Item.Height := Max_Y - Min_Y + 1;
         if Options.Make_Interior_Unchanged_Transparent then
            for Y in Min_Y .. Max_Y loop
               for X in Min_X .. Max_X loop
                  if Previous (Previous'First + Y * Natural (Width) + X)
                    = Current (Current'First + Y * Natural (Width) + X)
                  then
                     Item.Requires_Transparency := True;
                     exit;
                  end if;
               end loop;
               exit when Item.Requires_Transparency;
            end loop;
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
      Options : Optimization_Options := Default_Options) return Results.Result
   is
      Canvas_Pixels : constant Byte_Count := Byte_Count (Canvas_Width) * Byte_Count (Canvas_Height);
      Rectangle_Pixels : constant Byte_Count := Byte_Count (Item.Width) * Byte_Count (Item.Height);
      Output_Position : Natural := Output'First;
      Source_Position : Natural;
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
      for Y in Natural (Item.Top) .. Natural (Item.Top) + Item.Height - 1 loop
         for X in Natural (Item.Left) .. Natural (Item.Left) + Item.Width - 1 loop
            Source_Position := Y * Natural (Canvas_Width) + X;
            if Item.Requires_Transparency
              and then Options.Make_Interior_Unchanged_Transparent
              and then Previous (Previous'First + Source_Position)
                = Current (Current'First + Source_Position)
            then
               Output (Output_Position) := Byte (Options.Transparent_Index);
            else
               Output (Output_Position) := Current (Current'First + Source_Position);
            end if;
            Output_Position := Output_Position + 1;
         end loop;
      end loop;
      return Results.Success;
   end Extract_Indexed_Rectangle;
end Giflib.Optimization;
