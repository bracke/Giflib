package body Giflib.Internal.Optimization_Arithmetic with SPARK_Mode is
   function Include
     (Item : Change_Bounds;
      X : Pixel_Coordinate;
      Y : Pixel_Coordinate) return Change_Bounds
   is
   begin
      if Item.Empty then
         return
           (Empty => False,
            Min_X => X,
            Max_X => X,
            Min_Y => Y,
            Max_Y => Y);
      end if;
      return
        (Empty => False,
         Min_X => Pixel_Coordinate'Min (Item.Min_X, X),
         Max_X => Pixel_Coordinate'Max (Item.Max_X, X),
         Min_Y => Pixel_Coordinate'Min (Item.Min_Y, Y),
         Max_Y => Pixel_Coordinate'Max (Item.Max_Y, Y));
   end Include;

   function Width (Item : Change_Bounds) return Image_Width is
     (Image_Width (Item.Max_X - Item.Min_X + 1));

   function Height (Item : Change_Bounds) return Image_Height is
     (Image_Height (Item.Max_Y - Item.Min_Y + 1));

   function Is_Safe
     (Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean) return Boolean
   is
     (Palettes_Are_Equivalent
      and then Previous_Control.Disposal in 0 | 1
      and then Current_Control.Disposal in 0 | 1
      and then not Previous_Control.User_Input
      and then not Current_Control.User_Input
      and then not Previous_Control.Has_Transparency
      and then not Current_Control.Has_Transparency);

   function Can_Merge_Delay
     (Left, Right : Delay_Centiseconds) return Boolean
   is (Natural (Left) <= 65_535 - Natural (Right));

   function Merge_Delay
     (Left, Right : Delay_Centiseconds) return Delay_Centiseconds
   is (Delay_Centiseconds (Natural (Left) + Natural (Right)));
end Giflib.Internal.Optimization_Arithmetic;
