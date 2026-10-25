with Giflib.Metadata;

package Giflib.Internal.Wire_Format is
   pragma Pure;

   Extension_Introducer : constant Byte := 16#21#;
   Image_Separator : constant Byte := 16#2C#;
   Trailer : constant Byte := 16#3B#;
   Block_Terminator : constant Byte := 0;

   Plain_Text_Label : constant Byte :=
     Metadata.Plain_Text_Label;
   Graphic_Control_Label : constant Byte :=
     Metadata.Graphic_Control_Label;
   Comment_Label : constant Byte :=
     Metadata.Comment_Label;
   Application_Label : constant Byte :=
     Metadata.Application_Label;
end Giflib.Internal.Wire_Format;
