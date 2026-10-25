separate (Giflib.Testing.Test_Decoder_Allocation)
procedure Decoder_Metadata_Allocation_Failures
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : aliased Giflib.Streams.Memory_Source (Comment'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   Outcome : Giflib.Results.Result;

   procedure Run_Failure
     (Offset : Natural;
      Message : String;
      Check_Empty : Boolean := True) is
   begin
      Start (Source, Decoder, Options);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), Message & " header failed");
      Giflib.Decoding.Testing.Inject_Storage_Error_After (Decoder, Offset);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Require_Allocation_Failure (Outcome, Message & " Storage_Error escaped");
      if Check_Empty then
         Assert (Giflib.Decoding.Retained_Extension_Count (Decoder) = 0,
                 Message & " retained partial metadata");
      end if;
      Finish_Scenario (Decoder);
   end Run_Failure;
begin
   Options.Retention := Giflib.Metadata.Retain_All_Bounded;
   Run_Failure (0, "metadata extension-index", Check_Empty => False);
   Run_Failure (1, "metadata node");
   Run_Failure (2, "metadata chunk-index");
   Run_Failure (3, "metadata chunk");
exception
   when others =>
      Finish_Scenario (Decoder);
      raise;
end Decoder_Metadata_Allocation_Failures;
