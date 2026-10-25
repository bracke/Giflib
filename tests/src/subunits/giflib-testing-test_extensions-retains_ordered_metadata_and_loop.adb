separate (Giflib.Testing.Test_Extensions)
procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FE#, 3, 65, 66, 67, 2, 68, 69, 0,
      16#21#, 16#FF#, 11, 78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
      3, 1, 0, 0, 0,
      16#21#, 16#EE#, 1, 16#AA#, 0,
      16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Retained : Giflib.Metadata.Extension_Info;
   Payload : Giflib.Streams.Byte_Array (1 .. 20);
   Count : Giflib.Byte_Count;
   Chunk_Count : Natural;
   Outcome : Giflib.Results.Result;
   Labels : constant Giflib.Streams.Byte_Array := [16#FE#, 16#FF#, 16#EE#];
begin
   Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Outcome := Giflib.Decoding.Initialize (Decoder, Options);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   for Expected_Label of Labels loop
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "metadata event failed");
      Assert (Giflib.Metadata.Label_Of (Event.Extension) = Expected_Label,
              "metadata order changed");
   end loop;
   Assert (Giflib.Decoding.Retained_Extension_Count (Decoder) = 3,
           "retained extension count is wrong");
   Assert (Giflib.Decoding.Looping (Decoder).State = Giflib.Animations.Infinite_Looping,
           "infinite loop count was not recognized");

   Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 1, Retained);
   Assert (Giflib.Results.Succeeded (Outcome) and then Retained.Payload_Length = 5,
           "comment retention info is wrong");
   declare
      Constrained : Giflib.Metadata.Extension_Info
        (Kind => Giflib.Metadata.Application_Extension);
   begin
      Outcome := Giflib.Decoding.Retained_Extension_Info
        (Decoder, 1, Constrained);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch
         and then Constrained.Payload_Length = 0,
         "constrained retained metadata output raised or changed variant");
   end;
   Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload (Decoder, 1, Payload, Count);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 5,
           "comment retention copy failed");
   Assert (Payload (1 .. 5) = [65, 66, 67, 68, 69], "comment payload changed");
   Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count (Decoder, 1, Chunk_Count);
   Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
           "exact comment chunk count changed");
   Outcome := Giflib.Decoding.Copy_Retained_Extension_Chunk (Decoder, 1, 2, Payload, Count);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 2
           and then Payload (1 .. 2) = [68, 69],
           "exact comment chunk boundary changed");

   Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 2, Retained);
   Assert (Retained.Loop_Info.Is_Loop and then Retained.Loop_Info.Count = 0,
           "loop metadata was not retained");
   Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload (Decoder, 2, Payload, Count);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 14,
           "application payload retention failed");
end Retains_Ordered_Metadata_And_Loop;

