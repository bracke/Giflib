separate (Giflib.Testing.Test_Extensions)
procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Bad_GCE : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#F9#, 3, 0, 0, 0, 0];
   Large_Comment : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FE#, 3, 1, 2, 3, 2, 4, 5, 0];
   Fixed_GCE : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#F9#, 4, 0, 0, 0, 0, 0, 16#3B#];
   Fixed_Application : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FF#, 11, 65, 66, 67, 68, 69, 70, 71, 72, 49, 46, 48,
      0, 16#3B#];
   Application_With_Data : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FF#, 11, 65, 66, 67, 68, 69, 70, 71, 72, 49, 46, 48,
      1, 42, 0, 16#3B#];
   Fixed_Plain_Text : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#01#, 12, 0, 0, 0, 0, 1, 0, 1, 0, 8, 8, 1, 0,
      0, 16#3B#];
   Truncated_Application : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
      16#21#, 16#FF#, 11, 65, 66];
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Outcome : Giflib.Results.Result;

   procedure Decode_Extension
     (Fixture : not null access constant Giflib.Streams.Byte_Array;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Applied_Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits)
   is
      Source : aliased Giflib.Streams.Memory_Source (Fixture);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Options, Applied_Constraints);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
   end Decode_Extension;
begin
   Decode_Extension (Bad_GCE'Access);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Extension,
           "invalid GCE block size was accepted");

   Constraints.Max_Per_Extension_Bytes := 4;
   Decode_Extension
     (Large_Comment'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "per-extension budget was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
           "extension budget lost context");

   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Extensions := 0;
   Decode_Extension
     (Large_Comment'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Extension_Count_Limit,
           "extension count budget was ignored");

   declare
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   begin
      Options.Retention := Giflib.Metadata.Retain_All_Bounded;
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Retained_Metadata_Bytes := 4;
      Decode_Extension (Large_Comment'Access, Options, Constraints);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Retained_Metadata_Byte_Limit
              and then Outcome.First_Error.Context.Block = Giflib.Comment_Extension_Block
              and then Outcome.First_Error.Context.Extension_Label.Present
              and then Outcome.First_Error.Context.Extension_Label.Value = 16#FE#,
              "retained metadata budget was ignored");
   end;

   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Per_Extension_Bytes := 3;
   Decode_Extension (Fixed_GCE'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
           "fixed GCE payload escaped the per-extension budget");

   Constraints.Max_Per_Extension_Bytes := 10;
   Decode_Extension
     (Fixed_Application'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
           "fixed application header escaped the per-extension budget");

   Constraints.Max_Per_Extension_Bytes := 11;
   Decode_Extension
     (Application_With_Data'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit
           and then Outcome.First_Error.Context.Block
             = Giflib.Application_Extension_Block,
           "application sub-block budget lost its known block kind");

   Constraints.Max_Per_Extension_Bytes := 11;
   Decode_Extension
     (Fixed_Plain_Text'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
           "fixed plain-text header escaped the per-extension budget");

   Constraints := Giflib.Limits.Default_Limits;
   Decode_Extension
     (Truncated_Application'Access, Applied_Constraints => Constraints);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block
           and then Outcome.First_Error.Context.Block
             = Giflib.Application_Extension_Block,
           "known extension truncation reported the wrong block kind");
end Extension_Malformed_And_Budgets_Fail;

