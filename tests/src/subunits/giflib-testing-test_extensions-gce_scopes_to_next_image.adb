separate (Giflib.Testing.Test_Extensions)
procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     Header_With_Palette &
     [16#21#, 16#F9#, 4, 11, 5, 0, 1, 0] &
     [16#21#, 16#FE#, 1, 65, 0] &
     Image_1x1 & [16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Pixel : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Extension.Kind = Giflib.Metadata.Graphic_Control_Extension,
           "GCE event failed");
   Assert (Event.Extension.Graphic_Control.Disposal = 2
           and then Event.Extension.Graphic_Control.User_Input
           and then Event.Extension.Graphic_Control.Delay_CS = 5
           and then Event.Extension.Graphic_Control.Has_Transparency,
           "GCE event did not surface parsed control fields");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Extension.Kind = Giflib.Metadata.Comment_Extension,
           "comment between GCE and image failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.Image_Event,
           "image after GCE failed");
   Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
   Assert (Giflib.Results.Succeeded (Outcome), "GCE-controlled image failed");
   Assert (Info.Control.Disposal = 2, "GCE disposal was not scoped to image");
   Assert (Info.Control.User_Input, "GCE user-input flag was not scoped to image");
   Assert (Info.Control.Delay_CS = 5, "GCE delay was not retained");
   Assert (Info.Control.Has_Transparency and then Info.Control.Transparent_Index = 1,
           "GCE transparency was not retained");
end GCE_Scopes_To_Next_Image;
