with AUnit.Assertions;

with Giflib;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Policy is
   use AUnit.Assertions;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Warning_Code;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Streams.Byte_Array;

   procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("policy");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Trailing_Data_Policy'Access, "policy.trailing_data");
      Register_Routine (T, Safe_Missing_Trailer_Recovery'Access, "policy.safe_truncation");
      Register_Routine (T, Duplicate_And_Reserved_Policy'Access, "policy.duplicate_and_reserved");
   end Register_Tests;

   function Base_GIF (Trailer : Boolean := True) return Giflib.Streams.Byte_Array is
      Prefix : constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 1, 0];
   begin
      if Trailer then
         return Prefix & [16#3B#];
      end if;
      return Prefix;
   end Base_GIF;

   procedure Reach_End
     (Decoder : in out Giflib.Decoding.Decoder;
      Pixel : out Giflib.Streams.Byte_Array;
      Outcome : out Giflib.Results.Result)
   is
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
   begin
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      end if;
   end Reach_End;

   procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF & [99];
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Trailing_Data,
              "strict mode accepted trailing data");

      Options.Strictness := Giflib.Compatible;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset (Decoder, Source'Unchecked_Access, Options);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "compatible mode rejected trailing data");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "trailing warning was not recorded");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Assert (Warning.Code = Giflib.Errors.Trailing_Data_Ignored,
              "trailing warning has wrong code");
   end Trailing_Data_Policy;

   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF (Trailer => False);
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Options.Strictness := Giflib.Recover_When_Safe;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Options);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "safe missing-trailer recovery failed");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "recovery warning was not recorded");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Assert (Warning.Code = Giflib.Errors.Recovery_Applied, "recovery warning has wrong code");
   end Safe_Missing_Trailer_Recovery;

   procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#21#, 16#F9#, 4, 4, 0, 0, 0, 0,
         16#21#, 16#F9#, 4, 16, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 1, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Canvas : Giflib.Streams.Byte_Array (1 .. 4);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Duplicate_Graphic_Control,
              "strict mode accepted duplicate GCE");

      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Options.Strictness := Giflib.Compatible;
      Constraints.Max_Warning_Records := 1;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset (Decoder, Source'Unchecked_Access, Options, Constraints);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "compatible reserved disposal failed");
      Assert (Info.Control.Disposal = 4, "raw reserved disposal value was lost");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "warning limit was not enforced");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Assert (Warning.Code = Giflib.Errors.Warnings_Suppressed,
              "overflowed warning buffer did not report suppression");

      Giflib.Decoding.Finalize (Decoder);
      Constraints.Max_Warning_Records := 256;
      Constraints.Max_Diagnostic_Events := 0;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Source'Unchecked_Access, Options, Constraints);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 0,
              "diagnostic event budget was ignored");
   end Duplicate_And_Reserved_Policy;
end Giflib_Testing.Test_Policy;
