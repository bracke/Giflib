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

   subtype Known_Extension_Kind is Extension_Kind range
     Graphic_Control_Extension .. Application_Extension;

   Plain_Text_Label : constant Byte := 16#01#;
   Graphic_Control_Label : constant Byte := 16#F9#;
   Comment_Label : constant Byte := 16#FE#;
   Application_Label : constant Byte := 16#FF#;

   function Kind_Of (Label : Byte) return Extension_Kind is
     (case Label is
         when Graphic_Control_Label => Graphic_Control_Extension,
         when Comment_Label => Comment_Extension,
         when Plain_Text_Label => Plain_Text_Extension,
         when Application_Label => Application_Extension,
         when others => Unknown_Extension);

   function Label_Of (Kind : Known_Extension_Kind) return Byte is
     (case Kind is
         when Graphic_Control_Extension => Graphic_Control_Label,
         when Comment_Extension => Comment_Label,
         when Plain_Text_Extension => Plain_Text_Label,
         when Application_Extension => Application_Label);

   subtype Encodable_Extension_Kind is Extension_Kind range
     Comment_Extension .. Unknown_Extension;
   type Extension_Descriptor
     (Kind : Encodable_Extension_Kind := Unknown_Extension)
   is record
      case Kind is
         when Unknown_Extension =>
            Label : Byte := 0;
         when Comment_Extension |
              Plain_Text_Extension |
              Application_Extension =>
            null;
      end case;
   end record;

   function Label_Of (Descriptor : Extension_Descriptor) return Byte is
     (case Descriptor.Kind is
         when Comment_Extension .. Application_Extension =>
           Label_Of (Known_Extension_Kind (Descriptor.Kind)),
         when Unknown_Extension => Descriptor.Label);

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

   type Application_Loop_Info (Is_Loop : Boolean := False) is record
      case Is_Loop is
         when True =>
            Count : Natural range 0 .. 65_535 := 0;
         when False =>
            null;
      end case;
   end record;

   type Extension_Info (Kind : Extension_Kind := Unknown_Extension) is record
      Offset : Source_Offset := 0;
      Before_Frame : Frame_Ordinal := 0;
      Payload_Length : Byte_Count := 0;
      Sub_Block_Count : Natural := 0;
      case Kind is
         when Graphic_Control_Extension =>
            Graphic_Control : Frames.Graphic_Control := Frames.Default_Control;
         when Plain_Text_Extension =>
            Plain_Text : Plain_Text_Header;
         when Application_Extension =>
            Identifier : Application_Identifier := [others => 0];
            Authentication_Code : Application_Authentication_Code := [others => 0];
            Loop_Info : Application_Loop_Info;
         when Unknown_Extension =>
            Label : Byte := 0;
         when Comment_Extension =>
            null;
      end case;
   end record;

   function Label_Of (Info : Extension_Info) return Byte is
     (case Info.Kind is
         when Unknown_Extension => Info.Label,
         when Graphic_Control_Extension .. Application_Extension =>
           Label_Of (Known_Extension_Kind (Info.Kind)));
end Giflib.Metadata;
