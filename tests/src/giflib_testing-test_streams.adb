with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Streams is
   use AUnit.Assertions;
   use type Giflib.Byte_Count;
   use type Giflib.Destination_Offset;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Limit_Kind;
   use type Giflib.Source_Offset;
   use type Giflib.Streams.Byte_Array;

   procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Source_EOF_Skip_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Destination_Limits_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("streams");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Memory_Source_Handles_Short_Reads'Access, "streams.source.short_reads");
      Register_Routine (T, Source_EOF_Skip_And_Failures'Access, "streams.source.eof_zero_and_failure");
      Register_Routine (T, Fixed_Destination_Handles_Short_Writes'Access, "streams.destination.short_writes");
      Register_Routine (T, Destination_Limits_And_Failures'Access,
                        "streams.destination.limit_zero_and_failure");
   end Register_Tests;

   procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := [10, 20, 30, 40, 50];
      Target : Giflib.Streams.Byte_Array (1 .. 5) := (others => 0);
      Direct : Giflib.Streams.Byte_Array (1 .. 3) := (others => 0);
      Source : Giflib.Streams.Memory_Source;
      Step : Giflib.Streams.Source_Result;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 2);
      Step := Source.Read (Direct);
      Assert (Step.Count = 2 and then Direct (1 .. 2) = Input (1 .. 2), "short read returned wrong bytes");
      Assert (Source.Offset = 2 and then not Step.End_Of_Input, "short read returned wrong state");

      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Streams.Read_Exact (Source, Target);
      Assert (Giflib.Results.Succeeded (Outcome), "exact read rejected valid short reads");
      Assert (Target = Input, "exact read changed bytes");
      Assert (Source.Offset = 5, "exact read offset is wrong");
      Step := Source.Read (Direct);
      Assert (Step.Count = 0 and then Step.End_Of_Input, "EOF was not reported deterministically");
   end Memory_Source_Handles_Short_Reads;

   procedure Source_EOF_Skip_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := [1, 2, 3];
      Target : Giflib.Streams.Byte_Array (1 .. 4) := (others => 0);
      Source : Giflib.Streams.Memory_Source;
      Unopened : Giflib.Streams.Memory_Source;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Streams.Skip_Exact (Source, 2);
      Assert (Giflib.Results.Succeeded (Outcome) and then Source.Offset = 2, "partial skips were not completed");
      Outcome := Giflib.Streams.Skip_Exact (Source, 2);
      Assert (not Giflib.Results.Succeeded (Outcome), "skip beyond EOF succeeded");
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "skip EOF has wrong error");

      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 0);
      Outcome := Giflib.Streams.Read_Exact (Source, Target (1 .. 1));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Zero_Progress, "zero progress was not rejected");

      Giflib.Streams.Open (Source, Input'Unchecked_Access);
      Outcome := Giflib.Streams.Read_Exact (Source, Target);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "truncated read has wrong error");
      Assert (Outcome.First_Error.Context.Expected = 4 and then Outcome.First_Error.Context.Actual = 3,
              "truncated read has wrong diagnostic counts");

      Outcome := Giflib.Streams.Read_Exact (Unopened, Target (1 .. 1));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed, "source failure was not propagated");
   end Source_EOF_Skip_And_Failures;

   procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [7, 8, 9, 10, 11];
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Outcome : Giflib.Results.Result;
      Flush_Error : Giflib.Errors.Error;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Streams.Write_All (Destination, Input);
      Assert (Giflib.Results.Succeeded (Outcome), "write-all rejected valid short writes");
      Assert (Storage = Input, "write-all changed bytes");
      Assert (Destination.Offset = 5, "destination offset is wrong");
      Flush_Error := Destination.Flush;
      Assert (not Giflib.Errors.Is_Fatal (Flush_Error), "fixed destination flush failed");
   end Fixed_Destination_Handles_Short_Writes;

   procedure Destination_Limits_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [1, 2, 3, 4];
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0];
      Roomy : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Unopened : Giflib.Streams.Fixed_Buffer_Destination;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Streams.Write_All (Destination, Input);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "fixed-buffer overflow has wrong error");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit, "output limit context was lost");
      Assert (Destination.Offset = 2, "partial failure offset is wrong");

      Giflib.Streams.Open (Destination, Roomy'Unchecked_Access, Max_Transfer => 0);
      Outcome := Giflib.Streams.Write_All (Destination, Input);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Zero_Progress,
              "zero-progress write was not rejected");

      Outcome := Giflib.Streams.Write_All (Unopened, Input);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
              "destination failure was not propagated");
   end Destination_Limits_And_Failures;
end Giflib_Testing.Test_Streams;
