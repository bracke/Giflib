separate (Giflib.Testing.Test_Extensions)
procedure Covers_Retention_Policies_And_Bounds
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Fixture : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FE#, 3, 65, 66, 67, 0,
      16#21#, 16#FF#, 11, 78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
      3, 1, 3, 0, 0,
      16#21#, 16#EE#, 1, 16#AA#, 0,
      16#3B#];

   procedure Check
     (Policy : Giflib.Metadata.Retention_Policy;
      Expected_Count : Natural;
      Check_Bounds : Boolean := False)
   is
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Retained : Giflib.Metadata.Extension_Info;
      Small : Giflib.Streams.Byte_Array (1 .. 1);
      Count : Giflib.Byte_Count;
      Chunk_Count : Natural;
      Outcome : Giflib.Results.Result;
   begin
      Options.Retention := Policy;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome), "retention policy parsing failed");
         exit when Event.Kind = Giflib.Decoding.End_Event;
      end loop;
      Assert (Giflib.Decoding.Retained_Extension_Count (Decoder) = Expected_Count,
              "retention policy kept the wrong extensions");
      Assert (Giflib.Decoding.Looping (Decoder).State
                = Giflib.Animations.Finite_Loop_Count
              and then Giflib.Animations.Raw_Count
                (Giflib.Decoding.Looping (Decoder)) = 3,
              "finite loop parsing depended on payload retention");

      if Check_Bounds then
         Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 4, Retained);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Index,
                 "out-of-range retained info was accepted");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
           (Decoder, 4, Small, Count);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Index,
                 "out-of-range retained payload was accepted");
         Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count
           (Decoder, 4, Chunk_Count);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Index,
                 "out-of-range retained chunk count was accepted");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Chunk
           (Decoder, 1, 2, Small, Count);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Index,
                 "out-of-range retained chunk was accepted");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
           (Decoder, 1, Small, Count);
         Assert (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch,
                 "undersized retained payload target was accepted");
      end if;
      Giflib.Decoding.Finalize (Decoder);
   end Check;
begin
   Check (Giflib.Metadata.Discard_All, 0);
   Check (Giflib.Metadata.Parse_Known_Without_Retention, 0);
   Check (Giflib.Metadata.Retain_Selected, 2);
   Check (Giflib.Metadata.Retain_All_Bounded, 3, Check_Bounds => True);
end Covers_Retention_Policies_And_Bounds;

