with Ada.Finalization;

with Giflib;
with Giflib.Errors;
with Giflib.Results;
with Giflib.Streams;

package Giflib_Benchmark_Support is
   Benchmark_Error : exception;
   Performance_Guardrail_Error : exception;
   Guardrail_Failure_Status : constant := 2;
   Repeat_Count : constant := 5;
   Minimum_Timed_Sample : constant Duration := 0.020;
   Maximum_Batch_Iterations : constant Positive := 16_384;
   Minimum_Ceiling_Operations : constant Long_Float := 128.0;
   Operation_Allowance : constant Duration := 0.000003;
   Batch_Timing_Allowance : constant Duration := 0.000250;
   Decode_Pixels_Per_Second_Floor : constant := 52_000_000;
   Transcode_Pixels_Per_Second_Floor : constant := 20_000_000;
   Encode_Pixels_Per_Second_Floor : constant := 4_600_000;
   Fixed_Pixels_Per_Second_Floor : constant := 3_700_000;
   Cache_Friendly_Pixels_Per_Second_Floor : constant := 20_000_000;
   Cache_Phased_Pixels_Per_Second_Floor : constant := 18_500_000;
   Dither_Pixels_Per_Second_Floor : constant := 3_300_000;
   Alpha_Exact_Pixels_Per_Second_Floor : constant := 38_000_000;
   Alpha_Fixed_Pixels_Per_Second_Floor : constant := 3_600_000;
   Alpha_Dither_Pixels_Per_Second_Floor : constant := 3_600_000;
   LZW_Encode_Pixels_Per_Second_Floor : constant := 39_000_000;
   LZW_Decode_Pixels_Per_Second_Floor : constant := 85_000_000;
   Animation_Pixels_Per_Second_Floor : constant := 3_400_000;
   Optimization_Pixels_Per_Second_Floor : constant := 420_000_000;
   Peak_Memory_Ceiling_KiB : constant := 16_384;
   type Duration_Array is array (Positive range 1 .. Repeat_Count) of Duration;

   type Byte_Array_Access is access all Giflib.Streams.Byte_Array;
   type Owned_Buffer is new Ada.Finalization.Limited_Controlled with private;
   procedure Allocate (Object : in out Owned_Buffer; Length : Positive);
   function Is_Allocated (Object : Owned_Buffer) return Boolean;
   function Data (Object : Owned_Buffer) return not null Byte_Array_Access
     with Pre => Is_Allocated (Object);
   function Length (Object : Owned_Buffer) return Natural;

   type Counting_Destination is limited new Giflib.Streams.Destination
     with private;
   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error;

   procedure Sort (Values : in out Duration_Array);
   procedure Require
     (Outcome : Giflib.Results.Result;
      Operation : String;
      Workload : String);
   function Report_Peak_Memory return Natural;
   procedure Enforce_Time
     (Label : String; Observed : Duration; Ceiling : Duration);
   function Baseline_Sensitive_Ceiling
     (Label : String;
      Throughput_Ceiling : Duration;
      Reference : Duration) return Duration;
   function Repository_Root return String;
   function Measure_Batch
     (Process : not null access procedure;
      Batch_Iterations : Positive) return Duration;
   function Select_Batch_Iterations
     (Process : not null access procedure;
      Label : String) return Positive;
   function Batched_Throughput_Ceiling
     (Operations : Long_Float;
      Operations_Per_Second : Positive;
      Batch_Iterations : Positive) return Duration;
private
   overriding procedure Finalize (Object : in out Owned_Buffer);
   type Owned_Buffer is new Ada.Finalization.Limited_Controlled with record
      Value : Byte_Array_Access := null;
   end record;

   type Counting_Destination is limited new Giflib.Streams.Destination with record
      Position : Giflib.Destination_Offset := 0;
   end record;
end Giflib_Benchmark_Support;
