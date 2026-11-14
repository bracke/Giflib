with Ada.Finalization;

with Giflib;
with Giflib.Errors;
with Giflib.Results;
with Giflib.Streams;

package Giflib_Benchmark_Support is
   Benchmark_Error : exception;
   Repeat_Count : constant := 5;
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
private
   overriding procedure Finalize (Object : in out Owned_Buffer);
   type Owned_Buffer is new Ada.Finalization.Limited_Controlled with record
      Value : Byte_Array_Access := null;
   end record;

   type Counting_Destination is limited new Giflib.Streams.Destination with record
      Position : Giflib.Destination_Offset := 0;
   end record;
end Giflib_Benchmark_Support;
