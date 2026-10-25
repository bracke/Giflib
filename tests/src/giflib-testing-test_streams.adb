with AUnit.Assertions;

with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Encoding;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Stream_Arithmetic;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Streams is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Position_State;
   use type Giflib.Streams.Byte_Array;

   type Raising_Source is limited new Giflib.Streams.Source with null record;
   overriding function Read
     (Object : in out Raising_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Raising_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Raising_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   type Raising_Destination is limited new Giflib.Streams.Destination
     with null record;
   overriding function Write
     (Object : in out Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Raising_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Raising_Destination) return Giflib.Errors.Error;

   type Error_Source is limited new Giflib.Streams.Source with null record;
   overriding function Read
     (Object : in out Error_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Error_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Error_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   type Error_Destination is limited new Giflib.Streams.Destination
     with null record;
   overriding function Write
     (Object : in out Error_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Error_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Error_Destination) return Giflib.Errors.Error;

   type Counting_Source
     (Calls : not null access Natural)
      is limited new Giflib.Streams.Source with null record;
   overriding function Read
     (Object : in out Counting_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Counting_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Counting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   type Counting_Destination
     (Calls : not null access Natural;
      Fail_On_Call : Natural;
      Zero_Write : Boolean)
      is limited new Giflib.Streams.Destination with null record;
   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error;

   overriding function Read
     (Object : in out Raising_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      raise Program_Error;
      return (others => <>);
   end Read;

   overriding function Offset
     (Object : Raising_Source) return Giflib.Source_Offset
   is
      pragma Unreferenced (Object);
   begin
      raise Program_Error;
      return 0;
   end Offset;

   overriding function Skip
     (Object : in out Raising_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Count);
   begin
      raise Program_Error;
      return (others => <>);
   end Skip;

   overriding function Write
     (Object : in out Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      raise Program_Error;
      return (others => <>);
   end Write;

   overriding function Offset
     (Object : Raising_Destination) return Giflib.Destination_Offset
   is
      pragma Unreferenced (Object);
   begin
      raise Program_Error;
      return 0;
   end Offset;

   overriding function Flush
     (Object : in out Raising_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      raise Program_Error;
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   overriding function Read
     (Object : in out Error_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.Source_Read_Failed),
         Count => 0,
         End_Of_Input => False);
   end Read;

   overriding function Offset
     (Object : Error_Source) return Giflib.Source_Offset
   is
      pragma Unreferenced (Object);
   begin
      return 31;
   end Offset;

   overriding function Skip
     (Object : in out Error_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Count);
   begin
      return
        (Error => Giflib.Errors.Make
           (Giflib.Errors.Source_Read_Failed,
            (Source_Position => Giflib.Errors.Source_Position_At (7),
             others => <>)),
         Count => 0,
         End_Of_Input => False);
   end Skip;

   overriding function Write
     (Object : in out Error_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.Destination_Write_Failed),
         Count => 0);
   end Write;

   overriding function Offset
     (Object : Error_Destination) return Giflib.Destination_Offset
   is
      pragma Unreferenced (Object);
   begin
      return 41;
   end Offset;

   overriding function Flush
     (Object : in out Error_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      return Giflib.Errors.Make
        (Giflib.Errors.Destination_Write_Failed,
         (Destination_Position => Giflib.Errors.Destination_Position_At (8),
          others => <>));
   end Flush;

   overriding function Read
     (Object : in out Counting_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return (Count => 0, End_Of_Input => True, others => <>);
   end Read;

   overriding function Offset
     (Object : Counting_Source) return Giflib.Source_Offset
   is
   begin
      Object.Calls.all := Object.Calls.all + 1;
      return 17;
   end Offset;

   overriding function Skip
     (Object : in out Counting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Count);
   begin
      return (Count => 0, End_Of_Input => True, others => <>);
   end Skip;

   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array)
      return Giflib.Streams.Destination_Result
   is
   begin
      return
        (Count =>
           (if Object.Zero_Write
            then 0
            else Giflib.Byte_Count (Buffer'Length)),
         others => <>);
   end Write;

   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset
   is
   begin
      Object.Calls.all := Object.Calls.all + 1;
      if Object.Fail_On_Call /= 0
        and then Object.Calls.all = Object.Fail_On_Call
      then
         raise Program_Error;
      end if;
      return 23;
   end Offset;

   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Source_EOF_Skip_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Destination_Limits_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Callback_Exceptions_Are_Normalized
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Callback_Errors_Are_Decorated
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Diagnostic_Positions_Are_Sampled_Once
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Stream_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine (T, Callback_Exceptions_Are_Normalized'Access,
                        "streams.callback_exceptions");
      Register_Routine (T, Callback_Errors_Are_Decorated'Access,
                        "streams.callback_error_context");
      Register_Routine (T, Diagnostic_Positions_Are_Sampled_Once'Access,
                        "streams.position_sampling");
      Register_Routine (T, Stream_Arithmetic_Is_Bounded'Access,
                        "streams.arithmetic");
   end Register_Tests;

   procedure Stream_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Stream_Arithmetic;
      Ordinary : constant Arithmetic.Transfer_Plan :=
        Arithmetic.Plan_Transfer (Position => 3, Length => 10, Requested => 6, Maximum => 4);
      Edge : constant Arithmetic.Transfer_Plan :=
        Arithmetic.Plan_Transfer
          (Position => Natural'Last - 1,
           Length => Natural'Last,
           Requested => Natural'Last,
           Maximum => Giflib.Byte_Count'Last);
   begin
      Assert
        (Ordinary.Available = 7
         and then Ordinary.Count = 4
         and then Ordinary.Next_Position = 7,
         "ordinary transfer plan is wrong");
      Assert
        (Edge.Available = 1
         and then Edge.Count = 1
         and then Edge.Next_Position = Natural'Last,
         "maximum-position transfer plan overflowed");
      Assert
        (Arithmetic.Fits_Natural_Remaining (8, 10, 2)
         and then not Arithmetic.Fits_Natural_Remaining (8, 10, 3)
         and then Arithmetic.Advance_Natural (8, 10, 2) = 10,
         "natural progress accounting is wrong");
      Assert
        (Arithmetic.Fits_Count_Remaining
           (Giflib.Byte_Count'Last - 5, Giflib.Byte_Count'Last, 5)
         and then Arithmetic.Advance_Count
           (Giflib.Byte_Count'Last - 5, Giflib.Byte_Count'Last, 5)
             = Giflib.Byte_Count'Last,
         "byte-count progress accounting overflowed");
   end Stream_Arithmetic_Is_Bounded;

   procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := [10, 20, 30, 40, 50];
      Target : Giflib.Streams.Byte_Array (1 .. 5) := [others => 0];
      Direct : Giflib.Streams.Byte_Array (1 .. 3) := [others => 0];
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Step : Giflib.Streams.Source_Result;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Step := Source.Read (Direct);
      Assert (Step.Count = 2 and then Direct (1 .. 2) = Input (1 .. 2), "short read returned wrong bytes");
      Assert (Source.Offset = 2 and then not Step.End_Of_Input, "short read returned wrong state");

      Giflib.Streams.Open (Source, Max_Transfer => 2);
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
      Target : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Failed_Source : Raising_Source;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Streams.Skip_Exact (Source, 2);
      Assert (Giflib.Results.Succeeded (Outcome) and then Source.Offset = 2, "partial skips were not completed");
      Outcome := Giflib.Streams.Skip_Exact (Source, 2);
      Assert (not Giflib.Results.Succeeded (Outcome), "skip beyond EOF succeeded");
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "skip EOF has wrong error");

      Giflib.Streams.Open (Source, Max_Transfer => 0);
      Outcome := Giflib.Streams.Read_Exact (Source, Target (1 .. 1));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Zero_Progress, "zero progress was not rejected");
      Assert
        (Outcome.First_Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Outcome.First_Error.Context.Source_Position.Value = 0,
         "zero source offset was not preserved as present");

      Giflib.Streams.Open (Source);
      Outcome := Giflib.Streams.Read_Exact (Source, Target);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Unexpected_End, "truncated read has wrong error");
      Assert (Outcome.First_Error.Context.Expected = 4 and then Outcome.First_Error.Context.Actual = 3,
              "truncated read has wrong diagnostic counts");

      Outcome := Giflib.Streams.Read_Exact (Failed_Source, Target (1 .. 1));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed, "source failure was not propagated");
   end Source_EOF_Skip_And_Failures;

   procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [7, 8, 9, 10, 11];
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Outcome : Giflib.Results.Result;
      Flush_Error : Giflib.Errors.Error;
   begin
      Giflib.Streams.Open (Destination, Max_Transfer => 2);
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
      Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Roomy_Destination : Giflib.Streams.Fixed_Buffer_Destination (Roomy'Access);
      Failed_Destination : Raising_Destination;
      Outcome : Giflib.Results.Result;
      Written : Giflib.Byte_Count;
   begin
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Streams.Write_All (Destination, Input, Written);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "fixed-buffer overflow has wrong error");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit, "output limit context was lost");
      Assert (Destination.Offset = 2 and then Written = 2,
              "partial failure byte count is wrong");

      Giflib.Streams.Open (Roomy_Destination, Max_Transfer => 0);
      Outcome := Giflib.Streams.Write_All (Roomy_Destination, Input);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Zero_Progress,
              "zero-progress write was not rejected");
      Assert
        (Outcome.First_Error.Context.Destination_Position.State =
           Giflib.Errors.Position_Available
         and then Outcome.First_Error.Context.Destination_Position.Value = 0,
         "zero destination offset was not preserved as present");

      Outcome := Giflib.Streams.Write_All (Failed_Destination, Input);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
              "destination failure was not propagated");
   end Destination_Limits_And_Failures;

   procedure Callback_Exceptions_Are_Normalized
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : Raising_Source;
      Destination : Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
      Flush_Error : Giflib.Errors.Error;
   begin
      Outcome := Giflib.Streams.Read_Exact (Source, Buffer);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed,
         "raising source read escaped the stream facade");
      Outcome := Giflib.Streams.Skip_Exact (Source, 1);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed,
         "raising source skip escaped the stream facade");
      Assert
        (not Giflib.Streams.Position (Source).Available,
         "raising source offset was reported as available");

      Outcome := Giflib.Streams.Write_All (Destination, [1 => 1]);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
         "raising destination write escaped the stream facade");
      Assert
        (not Giflib.Streams.Position (Destination).Available,
         "raising destination offset was reported as available");
      Flush_Error := Giflib.Streams.Flush_Safely (Destination);
      Assert
        (Flush_Error.Code = Giflib.Errors.Destination_Write_Failed,
         "raising destination flush escaped the stream facade");
   end Callback_Exceptions_Are_Normalized;

   procedure Callback_Errors_Are_Decorated
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Returned_Source : Error_Source;
      Returned_Destination : Error_Destination;
      Buffer : Giflib.Streams.Byte_Array (1 .. 1);
      Source_Step : Giflib.Streams.Source_Result;
      Destination_Step : Giflib.Streams.Destination_Result;
      Flush_Error : Giflib.Errors.Error;
   begin
      Source_Step := Giflib.Streams.Read_Some (Returned_Source, Buffer);
      Assert
        (Source_Step.Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Source_Step.Error.Context.Source_Position.Value = 31,
         "source callback error did not receive its captured position");
      Source_Step := Giflib.Streams.Skip_Some (Returned_Source, 1);
      Assert
        (Source_Step.Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Source_Step.Error.Context.Source_Position.Value = 7,
         "source callback position overwrote existing diagnostic context");
      Destination_Step := Giflib.Streams.Write_Some
        (Returned_Destination, [1 => 1]);
      Assert
        (Destination_Step.Error.Context.Destination_Position.State =
           Giflib.Errors.Position_Available
         and then Destination_Step.Error.Context.Destination_Position.Value = 41,
         "destination callback error did not receive its captured position");
      Flush_Error := Giflib.Streams.Flush_Safely (Returned_Destination);
      Assert
        (Flush_Error.Context.Destination_Position.State =
           Giflib.Errors.Position_Available
         and then Flush_Error.Context.Destination_Position.Value = 8,
         "flush callback position overwrote existing diagnostic context");
   end Callback_Errors_Are_Decorated;

   procedure Diagnostic_Positions_Are_Sampled_Once
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Outcome : Giflib.Results.Result;
      Source_Calls : aliased Natural := 0;
      Destination_Calls : aliased Natural := 0;
      Retry_Calls : aliased Natural := 0;
      Truncated_Calls : aliased Natural := 0;
      Sequenced_Calls : aliased Natural := 0;
      Counted_Source : Counting_Source (Source_Calls'Access);
      Counted_Destination : Counting_Destination
        (Destination_Calls'Access, 0, False);
      Retry_Destination : aliased Counting_Destination
        (Retry_Calls'Access, 1, False);
      Retry_Encoder : Giflib.Encoding.Encoder (Retry_Destination'Access);
      Truncated_Source : aliased Counting_Source (Truncated_Calls'Access);
      Truncated_Decoder : Giflib.Decoding.Decoder (Truncated_Source'Access);
      Sequenced_Destination : aliased Counting_Destination
        (Sequenced_Calls'Access, 1, True);
      Sequenced_Encoder : Giflib.Encoding.Encoder
        (Sequenced_Destination'Access);
      Context : Giflib.Errors.Diagnostic_Context;
   begin
      Context := Giflib.Internal.Diagnostics.At_Source (Counted_Source);
      Context := Giflib.Internal.Diagnostics.At_Source
        (Counted_Source, Context);
      Assert
        (Source_Calls = 1
         and then Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Context.Source_Position.Value = 17,
         "source diagnostic sampled Offset more than once");
      Context := Giflib.Internal.Diagnostics.At_Destination
        (Counted_Destination);
      Context := Giflib.Internal.Diagnostics.At_Destination
        (Counted_Destination, Context);
      Assert
        (Destination_Calls = 1
         and then Context.Destination_Position.State =
           Giflib.Errors.Position_Available
         and then Context.Destination_Position.Value = 23,
         "destination diagnostic sampled Offset more than once");
      Outcome := Giflib.Encoding.Initialize (Retry_Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Initialize (Retry_Encoder);
      Assert
        (not Giflib.Results.Succeeded (Outcome)
         and then Retry_Calls = 1
         and then Outcome.First_Error.Context.Destination_Position.State =
           Giflib.Errors.Position_Unavailable,
         "encoder retried an unavailable diagnostic position");

      Outcome := Giflib.Decoding.Initialize (Truncated_Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      declare
         Header : Giflib.Decoding.Header_Info;
      begin
         Outcome := Giflib.Decoding.Read_Header (Truncated_Decoder, Header);
      end;
      Assert
        (not Giflib.Results.Succeeded (Outcome)
         and then Truncated_Calls = 2
         and then Outcome.First_Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available,
         "truncated-block decoration resampled the source position");

      Outcome := Giflib.Encoding.Initialize (Sequenced_Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Sequenced_Encoder, (others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Finish (Sequenced_Encoder);
      Assert
        (not Giflib.Results.Succeeded (Outcome)
         and then Sequenced_Calls = 1
         and then Outcome.First_Error.Context.Destination_Position.State =
           Giflib.Errors.Position_Unavailable,
         "zero-progress decoration resampled the destination position");
   end Diagnostic_Positions_Are_Sampled_Once;
end Giflib.Testing.Test_Streams;
