with Giflib.Frames;

package Giflib.Internal.Optimization_Arithmetic with SPARK_Mode is
   pragma Pure;

   subtype Pixel_Coordinate is Coordinate range 0 .. 65_534;

   type Change_Bounds is record
      Empty : Boolean := True;
      Min_X : Pixel_Coordinate := 0;
      Max_X : Pixel_Coordinate := 0;
      Min_Y : Pixel_Coordinate := 0;
      Max_Y : Pixel_Coordinate := 0;
   end record;

   function Include
     (Item : Change_Bounds;
      X : Pixel_Coordinate;
      Y : Pixel_Coordinate) return Change_Bounds
     with Post =>
       not Include'Result.Empty
       and then Include'Result.Min_X = (if Item.Empty then X else Pixel_Coordinate'Min (Item.Min_X, X))
       and then Include'Result.Max_X = (if Item.Empty then X else Pixel_Coordinate'Max (Item.Max_X, X))
       and then Include'Result.Min_Y = (if Item.Empty then Y else Pixel_Coordinate'Min (Item.Min_Y, Y))
       and then Include'Result.Max_Y = (if Item.Empty then Y else Pixel_Coordinate'Max (Item.Max_Y, Y));

   function Width (Item : Change_Bounds) return Image_Width
     with Pre => not Item.Empty and then Item.Min_X <= Item.Max_X,
          Post => Width'Result = Image_Width (Item.Max_X - Item.Min_X + 1);

   function Height (Item : Change_Bounds) return Image_Height
     with Pre => not Item.Empty and then Item.Min_Y <= Item.Max_Y,
          Post => Height'Result = Image_Height (Item.Max_Y - Item.Min_Y + 1);

   function Is_Safe
     (Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean) return Boolean
     with Post =>
       Is_Safe'Result =
         (Palettes_Are_Equivalent
          and then Previous_Control.Disposal in 0 | 1
          and then Current_Control.Disposal in 0 | 1
          and then not Previous_Control.User_Input
          and then not Current_Control.User_Input
          and then not Previous_Control.Has_Transparency
          and then not Current_Control.Has_Transparency);

   function Can_Merge_Delay
     (Left, Right : Delay_Centiseconds) return Boolean
     with Post =>
       Can_Merge_Delay'Result =
         (Natural (Left) <= 65_535 - Natural (Right));

   function Merge_Delay
     (Left, Right : Delay_Centiseconds) return Delay_Centiseconds
     with Pre => Can_Merge_Delay (Left, Right),
          Post => Merge_Delay'Result =
            Delay_Centiseconds (Natural (Left) + Natural (Right));
end Giflib.Internal.Optimization_Arithmetic;
