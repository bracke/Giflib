with Giflib.Decoding.Resource_Management;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Decoding.Canvas_Policy is
   type Background_Definition is record
      Color : Palettes.RGB_Color := (others => 0);
      Alpha : Byte := 0;
   end record;

   function Background_Of (Header : Header_Info) return Background_Definition is
   begin
      if Header.Has_Global_Palette and then Palettes.Contains
        (Header.Global_Palette, Header.Background_Index)
      then
         return
           (Color => Header.Global_Palette.Colors (Header.Background_Index),
            Alpha => 255);
      end if;
      return (others => <>);
   end Background_Of;

   function Setup_Canvas
     (Object : in out Decoder; Header : Header_Info) return Results.Result
   is
      Pixels : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Header.Width, Header.Height);
      Bytes : constant Byte_Count := Pixels * 4;
      Background : constant Background_Definition := Background_Of (Header);
      Outcome : Results.Result;
   begin
      if Pixels > Byte_Count (Object.Constraints.Max_Canvas_Pixels) then
         return Results.Failure
           (Errors.Make (Errors.Limit_Exceeded,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Expected => Byte_Count (Object.Constraints.Max_Canvas_Pixels),
                Actual => Pixels, Limit => Canvas_Pixel_Limit, others => <>))));
      elsif Bytes > Object.Constraints.Max_Canvas_Bytes then
         return Results.Failure
           (Errors.Make (Errors.Limit_Exceeded,
            Internal.Diagnostics.At_Source
              (Object.Input.all,
               (Expected => Object.Constraints.Max_Canvas_Bytes,
                Actual => Bytes, Limit => Canvas_Byte_Limit, others => <>))));
      end if;
      Outcome := Resource_Management.Ensure_Canvas (Object, Bytes);
      if not Results.Succeeded (Outcome) then return Outcome; end if;
      return Internal.Decoder_Storage.Image_Operations.Initialize_Canvas
        (Object.Resources, Pixels, Background.Color, Background.Alpha);
   end Setup_Canvas;

   function Fill_Background
     (Object : in out Decoder; Rectangle : Frames.Rectangle)
      return Results.Result
   is
      Background : constant Background_Definition :=
        Background_Of (Object.Header_Data);
   begin
      return Internal.Decoder_Storage.Image_Operations.Fill_Canvas_Rectangle
        (Object.Resources, Object.Header_Data.Width, Rectangle,
         Background.Color, Background.Alpha);
   end Fill_Background;
end Giflib.Decoding.Canvas_Policy;
