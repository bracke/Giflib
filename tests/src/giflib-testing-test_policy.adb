with AUnit.Assertions;

with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Policy is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Warning_Code;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Streams.Byte_Array;

   type Overreporting_Source
     (Storage : not null access constant Giflib.Streams.Byte_Array)
      is limited new Giflib.Streams.Source with record
      Backing : Giflib.Streams.Memory_Source (Storage);
   end record;

   overriding function Read
     (Object : in out Overreporting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Overreporting_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Overreporting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Image_Descriptor_Reserved_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine
        (T,
         Image_Descriptor_Reserved_Policy'Access,
         "policy.image_descriptor_reserved");
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

   overriding function Read
     (Object : in out Overreporting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result
   is
      Step : Giflib.Streams.Source_Result := Object.Backing.Read (Buffer);
   begin
      if Step.Count = 0 and then Step.End_Of_Input then
         Step.Count := 2;
         Step.End_Of_Input := False;
      end if;
      return Step;
   end Read;

   overriding function Offset
     (Object : Overreporting_Source) return Giflib.Source_Offset is
   begin
      return Object.Backing.Offset;
   end Offset;

   overriding function Skip
     (Object : in out Overreporting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result is
   begin
      return Object.Backing.Skip (Count);
   end Skip;

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
      Exact_Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF;
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Over_Source : aliased Overreporting_Source (Exact_Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Over_Decoder : Giflib.Decoding.Decoder (Over_Source'Access);
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Trailing_Data,
              "strict mode accepted trailing data");

      Options.Strictness := Giflib.Compatible;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Reset (Decoder, Options);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "compatible mode rejected trailing data");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "trailing warning was not recorded");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Assert (Warning.Code = Giflib.Errors.Trailing_Data_Ignored,
              "trailing warning has wrong code");

      Options := Giflib.Decoding.Default_Options;
      Giflib.Streams.Open
        (Over_Source.Backing);
      Outcome := Giflib.Decoding.Initialize
        (Over_Decoder, Options);
      Reach_End (Over_Decoder, Pixel, Outcome);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
         and then Outcome.First_Error.Context.Actual = 2,
         "trailing-data probe accepted an over-reported read count");
   end Trailing_Data_Policy;

   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := Base_GIF (Trailer => False);
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Options.Strictness := Giflib.Recover_When_Safe;
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Options);
      Reach_End (Decoder, Pixel, Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "safe missing-trailer recovery failed");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "recovery warning was not recorded");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Giflib.Testing.Assertions.Require_Success (Outcome);
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
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Canvas : Giflib.Streams.Byte_Array (1 .. 4);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Duplicate_Graphic_Control,
              "strict mode accepted duplicate GCE");

      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Options.Strictness := Giflib.Compatible;
      Constraints.Max_Warning_Records := 1;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Reset (Decoder, Options, Constraints);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "compatible reserved disposal failed");
      Assert (Info.Control.Disposal = 4, "raw reserved disposal value was lost");
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 1, "warning limit was not enforced");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Assert (Warning.Code = Giflib.Errors.Warnings_Suppressed,
              "overflowed warning buffer did not report suppression");

      Giflib.Decoding.Finalize (Decoder);
      Constraints.Max_Warning_Records := 256;
      Constraints.Max_Diagnostic_Events := 0;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Options, Constraints);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Assert (Giflib.Decoding.Warning_Count (Decoder) = 0,
              "diagnostic event budget was ignored");
   end Duplicate_And_Reserved_Policy;

   procedure Image_Descriptor_Reserved_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 16#08#,
         2, 2, 16#44#, 1, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Warning : Giflib.Errors.Warning;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block,
              "strict mode accepted reserved image-descriptor bits");
      Assert
        (Outcome.First_Error.Context.Block = Giflib.Image_Descriptor_Block
         and then Outcome.First_Error.Context.Source = 28
         and then Outcome.First_Error.Context.Actual = 8,
         "reserved image-descriptor diagnostic context is wrong");

      Options.Strictness := Giflib.Compatible;
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Reset
        (Decoder, Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert
        (Giflib.Results.Succeeded (Outcome) and then Pixel = [0],
         "compatible mode rejected reserved image-descriptor bits");
      Assert
        (Giflib.Decoding.Warning_Count (Decoder) = 1,
         "compatible reserved image-descriptor warning was not recorded");
      Outcome := Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Assert
        (Warning.Code = Giflib.Errors.Reserved_Value_Accepted
         and then Warning.Context.Block = Giflib.Image_Descriptor_Block
         and then Warning.Context.Source = 28
         and then Warning.Context.Actual = 8,
         "compatible reserved image-descriptor warning context is wrong");
   end Image_Descriptor_Reserved_Policy;
end Giflib.Testing.Test_Policy;
