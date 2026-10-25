separate (Giflib.Testing.Test_Decoder)
procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
   Extension_Stream : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#21#, 16#FE#, 0, 16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Other_Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Extension_Source : aliased Giflib.Streams.Memory_Source (Extension_Stream'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Other : Giflib.Decoding.Decoder (Other_Source'Access);
   Extension_Decoder : Giflib.Decoding.Decoder (Extension_Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;
begin
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
           "read-before-initialize was accepted");
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture image event failed");
   Outcome := Giflib.Decoding.Cancel (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "cancellation failed");
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Cancelled,
           "cancellation state is wrong");

   Giflib.Streams.Open (Other_Source);
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Decoding.Reset (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "reset failed");
   Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized,
           "reset state is wrong");

   Options.Mode := Giflib.Decoding.Expanded_Frame;
   Outcome := Giflib.Decoding.Initialize (Other, Options);
   Assert (Giflib.Results.Succeeded (Outcome), "expanded-frame mode initialization failed");
   Giflib.Decoding.Finalize (Other);

   Giflib.Streams.Open (Extension_Source);
   Outcome := Giflib.Decoding.Initialize
     (Extension_Decoder);
   Assert (Giflib.Results.Succeeded (Outcome), "extension fixture reset failed");
   Outcome := Giflib.Decoding.Read_Header (Extension_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome), "extension fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Extension_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome), "comment extension failed");
   Assert (Event.Kind = Giflib.Decoding.Extension_Event
           and then Giflib.Metadata.Label_Of (Event.Extension) = 16#FE#,
           "comment extension event lost its label");
end State_Cancel_Reset_And_Unsupported;
