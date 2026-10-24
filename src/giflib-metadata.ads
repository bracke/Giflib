with Giflib.Frames;

package Giflib.Metadata is
   pragma Pure;

   type Retention_Policy is
     (Discard_All,
      Parse_Known_Without_Retention,
      Retain_Selected,
      Retain_All_Bounded,
      Retain_All_Exact_Bounded);

   type Extension_Kind is
     (Graphic_Control_Extension,
      Comment_Extension,
      Plain_Text_Extension,
      Application_Extension,
      Unknown_Extension);

   type Application_Identifier is array (Positive range 1 .. 8) of Byte;
   type Application_Authentication_Code is array (Positive range 1 .. 3) of Byte;

   type Plain_Text_Header is record
      Grid_Left : Natural range 0 .. 65_535 := 0;
      Grid_Top : Natural range 0 .. 65_535 := 0;
      Grid_Width : Natural range 0 .. 65_535 := 0;
      Grid_Height : Natural range 0 .. 65_535 := 0;
      Cell_Width : Byte := 0;
      Cell_Height : Byte := 0;
      Foreground_Index : Palette_Index := 0;
      Background_Index : Palette_Index := 0;
   end record;

   type Extension_Info is record
      Kind : Extension_Kind := Unknown_Extension;
      Label : Byte := 0;
      Offset : Source_Offset := 0;
      Before_Frame : Frame_Ordinal := 0;
      Payload_Length : Byte_Count := 0;
      Sub_Block_Count : Natural := 0;
      Has_Graphic_Control : Boolean := False;
      Graphic_Control : Frames.Graphic_Control := Frames.Default_Control;
      Has_Plain_Text_Header : Boolean := False;
      Plain_Text : Plain_Text_Header;
      Has_Application_Identifier : Boolean := False;
      Identifier : Application_Identifier := [others => 0];
      Authentication_Code : Application_Authentication_Code := [others => 0];
      Is_Loop_Extension : Boolean := False;
      Loop_Count : Natural range 0 .. 65_535 := 0;
   end record;
end Giflib.Metadata;
