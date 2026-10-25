with AUnit.Assertions;
with Giflib.Decoding;
with Giflib.Decoding.Testing;
with Giflib.Errors;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Decoder_Allocation is
   use AUnit.Assertions;
   use type Giflib.Decoding.Decoder_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;

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

   procedure Require_Allocation_Failure
     (Outcome : Giflib.Results.Result;
      Message : String);
   procedure Start
     (Source : in out Giflib.Streams.Memory_Source;
      Decoder : in out Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options);
   procedure Finish_Scenario (Decoder : in out Giflib.Decoding.Decoder);

   procedure Decoder_Core_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
   procedure Decoder_Metadata_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
   procedure Decoder_Cleanup_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
   procedure Decoder_Snapshot_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
   procedure Decoder_Scratch_Reuse
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
   procedure Decoder_Snapshot_Reuse
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Start
     (Source : in out Giflib.Streams.Memory_Source;
      Decoder : in out Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options)
   is
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder, Options);
      Assert (Giflib.Results.Succeeded (Outcome),
              "allocation fixture initialization failed");
   end Start;

   procedure Finish_Scenario (Decoder : in out Giflib.Decoding.Decoder) is
   begin
      Giflib.Decoding.Testing.Disable_Failure_Injection (Decoder);
      Giflib.Decoding.Finalize (Decoder);
   end Finish_Scenario;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("decoder_allocation");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Decoder_Core_Allocation_Failures'Access,
         "allocation_failures.decoder_core");
      Register_Routine
        (T, Decoder_Metadata_Allocation_Failures'Access,
         "allocation_failures.decoder_metadata");
      Register_Routine
        (T, Decoder_Cleanup_Failures'Access,
         "allocation_failures.decoder_cleanup");
      Register_Routine
        (T, Decoder_Snapshot_Allocation_Failures'Access,
         "allocation_failures.decoder_snapshot");
      Register_Routine
        (T, Decoder_Scratch_Reuse'Access,
         "allocation_reuse.decoder_scratch");
      Register_Routine
        (T, Decoder_Snapshot_Reuse'Access,
         "allocation_reuse.decoder_snapshot");
   end Register_Tests;

   procedure Require_Allocation_Failure
     (Outcome : Giflib.Results.Result;
      Message : String) is
   begin
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
         and then Outcome.First_Error.Context.Limit =
           Giflib.Allocation_Byte_Limit,
         Message);
   end Require_Allocation_Failure;
end Giflib.Testing.Test_Decoder_Allocation;
