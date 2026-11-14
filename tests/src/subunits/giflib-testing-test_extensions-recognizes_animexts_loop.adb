separate (Giflib.Testing.Test_Extensions)
procedure Recognizes_Animexts_Loop
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FF#, 11,
      65, 78, 73, 77, 69, 88, 84, 83, 49, 46, 48,
      3, 1, 5, 0, 0,
      16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Outcome := Giflib.Decoding.Initialize (Decoder);
   Assert (Giflib.Results.Succeeded (Outcome),
           "ANIMEXTS fixture initialization failed");
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "ANIMEXTS fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Extension_Event
           and then Event.Extension.Kind = Giflib.Metadata.Application_Extension
           and then Event.Extension.Loop_Info.Is_Loop
           and then Event.Extension.Loop_Info.Count = 5
           and then Giflib.Decoding.Looping (Decoder).State
             = Giflib.Animations.Finite_Loop_Count
           and then Giflib.Animations.Raw_Count
             (Giflib.Decoding.Looping (Decoder)) = 5,
           "ANIMEXTS finite loop was not recognized");
end Recognizes_Animexts_Loop;
