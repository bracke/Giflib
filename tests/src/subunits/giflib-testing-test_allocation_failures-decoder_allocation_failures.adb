separate (Giflib.Testing.Test_Allocation_Failures)
procedure Decoder_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Plain : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0, 16#3B#];
   Two_Frames : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0, 16#3B#];
   Restore_Previous : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#21#, 16#F9#, 4, 12, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0, 16#3B#];
   Restore_Previous_Twice : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#21#, 16#F9#, 4, 12, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0,
      16#21#, 16#F9#, 4, 12, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 16#01#, 0, 16#3B#];
   Comment : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FE#, 3, 65, 66, 67, 0, 16#3B#];
   Plain_Source : aliased Giflib.Streams.Memory_Source (Plain'Access);
   Plain_Decoder : Giflib.Decoding.Decoder (Plain_Source'Access);
   Comment_Source : aliased Giflib.Streams.Memory_Source (Comment'Access);
   Comment_Decoder : Giflib.Decoding.Decoder (Comment_Source'Access);
   Restore_Source : aliased Giflib.Streams.Memory_Source (Restore_Previous'Access);
   Restore_Decoder : Giflib.Decoding.Decoder (Restore_Source'Access);
   Two_Source : aliased Giflib.Streams.Memory_Source (Two_Frames'Access);
   Two_Decoder : Giflib.Decoding.Decoder (Two_Source'Access);
   Restore_Twice_Source : aliased Giflib.Streams.Memory_Source
     (Restore_Previous_Twice'Access);
   Restore_Twice_Decoder : Giflib.Decoding.Decoder
     (Restore_Twice_Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Canvas : Giflib.Streams.Byte_Array (1 .. 4);
   Options : Giflib.Decoding.Decode_Options :=
     Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;

   procedure Start
     (Source : in out Giflib.Streams.Memory_Source;
      Decoder : in out Giflib.Decoding.Decoder;
      Decode_Options : Giflib.Decoding.Decode_Options)
   is
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Decode_Options);
      Assert (Giflib.Results.Succeeded (Outcome),
              "allocation fixture initialization failed");
   end Start;

   procedure Finish_Scenario (Decoder : in out Giflib.Decoding.Decoder) is
   begin
      Giflib.Decoding.Testing.Disable_Failure_Injection (Decoder);
      Giflib.Decoding.Finalize (Decoder);
   end Finish_Scenario;
begin
   Giflib.Decoding.Testing.Disable_Failure_Injection (Plain_Decoder);

   Options := Giflib.Decoding.Default_Options;
   Start (Plain_Source, Plain_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Plain_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "LZW-workspace fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Plain_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "LZW-workspace fixture did not reach its image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Plain_Decoder);
   Outcome := Giflib.Decoding.Decode_Indexed_Frame
     (Plain_Decoder, Canvas (1 .. 1), Info);
   Require_Allocation_Failure
     (Outcome, "decoder LZW-workspace Storage_Error escaped");
   Assert (Giflib.Decoding.Testing.Allocated_Bytes (Plain_Decoder) = 0,
           "failed decoder LZW allocation retained its budget charge");
   Finish_Scenario (Plain_Decoder);

   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Start (Plain_Source, Plain_Decoder, Options);
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Plain_Decoder);
   Outcome := Giflib.Decoding.Read_Header (Plain_Decoder, Header);
   Require_Allocation_Failure (Outcome, "canvas Storage_Error escaped");
   Assert (Giflib.Decoding.State (Plain_Decoder) = Giflib.Decoding.Failed,
           "canvas allocation failure did not fail the decoder");
   Finish_Scenario (Plain_Decoder);

   Options := Giflib.Decoding.Default_Options;
   Options.Retention := Giflib.Metadata.Retain_All_Bounded;
   Start (Comment_Source, Comment_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Comment_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "metadata-node fixture header failed");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Comment_Decoder);
   Outcome := Giflib.Decoding.Next_Event (Comment_Decoder, Event);
   Require_Allocation_Failure
     (Outcome, "metadata extension-index Storage_Error escaped");
   Finish_Scenario (Comment_Decoder);

   Start (Comment_Source, Comment_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Comment_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "metadata-chunk fixture header failed");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Comment_Decoder, 1);
   Outcome := Giflib.Decoding.Next_Event (Comment_Decoder, Event);
   Require_Allocation_Failure (Outcome, "metadata-node Storage_Error escaped");
   Assert (Giflib.Decoding.Retained_Extension_Count (Comment_Decoder) = 0,
           "partially retained metadata survived allocation failure");
   Finish_Scenario (Comment_Decoder);

   Start (Comment_Source, Comment_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Comment_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "metadata chunk-index fixture header failed");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Comment_Decoder, 2);
   Outcome := Giflib.Decoding.Next_Event (Comment_Decoder, Event);
   Require_Allocation_Failure
     (Outcome, "metadata chunk-index Storage_Error escaped");
   Assert (Giflib.Decoding.Retained_Extension_Count (Comment_Decoder) = 0,
           "metadata survived chunk-index allocation failure");
   Finish_Scenario (Comment_Decoder);

   Start (Comment_Source, Comment_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Comment_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "metadata chunk fixture header failed");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Comment_Decoder, 3);
   Outcome := Giflib.Decoding.Next_Event (Comment_Decoder, Event);
   Require_Allocation_Failure (Outcome, "metadata-chunk Storage_Error escaped");
   Assert (Giflib.Decoding.Retained_Extension_Count (Comment_Decoder) = 0,
           "metadata survived chunk allocation failure");
   Finish_Scenario (Comment_Decoder);

   Options := Giflib.Decoding.Default_Options;
   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Start (Restore_Source, Restore_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Restore_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "snapshot fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Extension_Event,
           "snapshot fixture control extension failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "snapshot allocation fixture did not reach its image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Restore_Decoder);
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Restore_Decoder, Canvas, Info);
   Require_Allocation_Failure (Outcome, "snapshot Storage_Error escaped");
   Finish_Scenario (Restore_Decoder);

   Start (Plain_Source, Plain_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Plain_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "frame-index fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Plain_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "frame-index fixture did not reach its image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Plain_Decoder);
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Plain_Decoder, Canvas, Info);
   Require_Allocation_Failure (Outcome, "frame-index Storage_Error escaped");
   Finish_Scenario (Plain_Decoder);

   Start (Two_Source, Two_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Two_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "scratch-reuse fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Two_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "scratch-reuse fixture did not reach its first image");
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Two_Decoder, Canvas, Info);
   Assert (Giflib.Results.Succeeded (Outcome),
           "scratch-reuse fixture first frame failed");
   Outcome := Giflib.Decoding.Next_Event (Two_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "scratch-reuse fixture did not reach its second image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Two_Decoder);
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Two_Decoder, Canvas, Info);
   Assert (Giflib.Results.Succeeded (Outcome),
           "same-sized composited frame allocated a new scratch buffer");
   Finish_Scenario (Two_Decoder);

   Start (Restore_Twice_Source, Restore_Twice_Decoder, Options);
   Outcome := Giflib.Decoding.Read_Header (Restore_Twice_Decoder, Header);
   Assert (Giflib.Results.Succeeded (Outcome),
           "snapshot-reuse fixture header failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Twice_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Extension_Event,
           "snapshot-reuse fixture first control failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Twice_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "snapshot-reuse fixture did not reach its first image");
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Restore_Twice_Decoder, Canvas, Info);
   Assert (Giflib.Results.Succeeded (Outcome),
           "snapshot-reuse fixture first frame failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Twice_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Extension_Event,
           "snapshot-reuse fixture second control failed");
   Outcome := Giflib.Decoding.Next_Event (Restore_Twice_Decoder, Event);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Event.Kind = Giflib.Decoding.Image_Event,
           "snapshot-reuse fixture did not reach its second image");
   Giflib.Decoding.Testing.Inject_Storage_Error_After (Restore_Twice_Decoder);
   Outcome := Giflib.Decoding.Decode_Composited_Frame
     (Restore_Twice_Decoder, Canvas, Info);
   Assert (Giflib.Results.Succeeded (Outcome),
           "same-sized restore snapshot allocated a new buffer");
   Finish_Scenario (Restore_Twice_Decoder);
exception
   when others =>
      Giflib.Decoding.Testing.Disable_Failure_Injection (Plain_Decoder);
      Giflib.Decoding.Testing.Disable_Failure_Injection (Comment_Decoder);
      Giflib.Decoding.Testing.Disable_Failure_Injection (Restore_Decoder);
      Giflib.Decoding.Testing.Disable_Failure_Injection (Two_Decoder);
      Giflib.Decoding.Testing.Disable_Failure_Injection
        (Restore_Twice_Decoder);
      raise;
end Decoder_Allocation_Failures;

