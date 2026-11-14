with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Session_Arithmetic;

package body Giflib.Encoding.Request_Validation is
   use type Animations.Loop_State;
   use type Frames.Graphic_Control;
   package Geometry_Arithmetic renames Internal.Geometry_Arithmetic;
   package Session_Arithmetic renames Internal.Session_Arithmetic;

   function Has_Extension_Room
     (Object : Encoder; Additional : Natural) return Boolean
   is
     (Session_Arithmetic.Has_Natural_Capacity
        (Object.Extensions_Written, Object.Constraints.Max_Extensions,
         Additional));

   function Validate_Screen
     (Object : Encoder; Screen : Screen_Info) return Results.Result
   is
      Pixels : constant Byte_Count :=
        Geometry_Arithmetic.Area (Screen.Width, Screen.Height);
   begin
      if Screen.Width > Object.Constraints.Max_Logical_Width then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Logical_Width),
                Actual => Byte_Count (Screen.Width),
                Limit => Logical_Width_Limit, others => <>)));
      elsif Screen.Height > Object.Constraints.Max_Logical_Height then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Logical_Height),
                Actual => Byte_Count (Screen.Height),
                Limit => Logical_Height_Limit, others => <>)));
      elsif Pixels > Byte_Count (Object.Constraints.Max_Canvas_Pixels) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Canvas_Pixels),
                Actual => Pixels, Limit => Canvas_Pixel_Limit, others => <>)));
      end if;
      return Results.Success;
   end Validate_Screen;

   function Validate_Global_Palette
     (Object : Encoder; Palette : Palettes.Palette) return Results.Result is
   begin
      if Palette.Length < 2 then
         return Results.Failure (Errors.Make (Errors.Missing_Color_Table));
      elsif not Palettes.Contains
        (Palette, Object.Screen.Background_Index)
      then
         return Results.Failure
           (Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      return Results.Success;
   end Validate_Global_Palette;

   function Validate_Loop_Count
     (Object : Encoder; Count : Natural) return Results.Result is
   begin
      if Count > 65_535 then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      elsif Object.Options.Version = Force_GIF87a then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      elsif Object.Loop_Data.State = Animations.No_Loop_Extension
        and then not Has_Extension_Room (Object, 1)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Validate_Loop_Count;

   function Validate_Frame
     (Object : Encoder; Info : Frame_Info) return Results.Result
   is
      Geometry : constant Geometry_Arithmetic.Rectangle_Analysis :=
        Geometry_Arithmetic.Analyze_Rectangle
          (Info.Left, Info.Top, Info.Width, Info.Height,
           Object.Screen.Width, Object.Screen.Height);
      Additional_Extensions : constant Natural :=
        (if Object.Loop_Data.State /= Animations.No_Loop_Extension
             and then Object.Current_State = Screen_Defined
         then 1 else 0)
        + (if Info.Control /= Frames.Default_Control then 1 else 0);
   begin
      if Object.Frames_Written >= Object.Constraints.Max_Frames then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Frames),
                Actual => Byte_Count (Object.Frames_Written) + 1,
                Limit => Frame_Count_Limit,
                others => <>)));
      elsif Geometry.Pixel_Area > Byte_Count (Object.Constraints.Max_Frame_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Frame_Pixels),
                Actual => Geometry.Pixel_Area,
                Limit => Frame_Pixel_Limit,
                others => <>)));
      elsif not Geometry.Fits then
         return Results.Failure (Errors.Make (Errors.Frame_Out_Of_Bounds));
      elsif Object.Options.Version = Force_GIF87a
        and then Info.Control /= Frames.Default_Control
      then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      elsif not Has_Extension_Room (Object, Additional_Extensions) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written)
                  + Byte_Count (Additional_Extensions),
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Validate_Frame;
end Giflib.Encoding.Request_Validation;
