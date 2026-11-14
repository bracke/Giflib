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

   procedure Stream_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Source_EOF_Skip_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Destination_Limits_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Callback_Exceptions_Are_Normalized
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Callback_Errors_Are_Decorated
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Diagnostic_Positions_Are_Sampled_Once
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Streams;
