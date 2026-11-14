with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Giflib_Platform_Services;

package body Giflib_Benchmark_Support is
   use type Giflib.Destination_Offset;

   procedure Free is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, Byte_Array_Access);

   procedure Allocate (Object : in out Owned_Buffer; Length : Positive) is
      Replacement : Byte_Array_Access;
   begin
      begin
         Replacement := new Giflib.Streams.Byte_Array (1 .. Length);
      exception
         when Storage_Error =>
            raise Benchmark_Error with
              "cannot allocate benchmark buffer of"
              & Positive'Image (Length) & " bytes";
      end;
      if Object.Value /= null then
         Free (Object.Value);
      end if;
      Object.Value := Replacement;
   end Allocate;

   function Is_Allocated (Object : Owned_Buffer) return Boolean is
     (Object.Value /= null);

   function Data (Object : Owned_Buffer) return not null Byte_Array_Access is
     (Object.Value);

   function Length (Object : Owned_Buffer) return Natural is
     (if Object.Value = null then 0 else Object.Value'Length);

   overriding procedure Finalize (Object : in out Owned_Buffer) is
   begin
      if Object.Value /= null then
         Free (Object.Value);
      end if;
   end Finalize;

   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result
   is
   begin
      Object.Position := Object.Position
        + Giflib.Destination_Offset (Buffer'Length);
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Buffer'Length));
   end Write;

   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset
   is (Object.Position);

   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   procedure Sort (Values : in out Duration_Array) is
      Item : Duration;
      Position : Positive;
   begin
      for I in Values'First + 1 .. Values'Last loop
         Item := Values (I);
         Position := I;
         while Position > Values'First
           and then Values (Position - 1) > Item
         loop
            Values (Position) := Values (Position - 1);
            Position := Position - 1;
         end loop;
         Values (Position) := Item;
      end loop;
   end Sort;

   procedure Require
     (Outcome : Giflib.Results.Result;
      Operation : String;
      Workload : String) is
   begin
      if not Giflib.Results.Succeeded (Outcome) then
         raise Benchmark_Error with
           Operation & " failed: " & Workload & " "
           & Giflib.Errors.Error_Code'Image (Outcome.First_Error.Code);
      end if;
   end Require;

   function Report_Peak_Memory return Natural is
      Metric : constant Giflib_Platform_Services.Memory_Metric :=
        Giflib_Platform_Services.Peak_Memory;
   begin
      if not Metric.Available then
         Ada.Text_IO.Put_Line ("process_peak_rss_kib=unavailable");
         return 0;
      end if;
      Ada.Text_IO.Put_Line
        ("process_peak_rss_kib=" & Natural'Image (Metric.KiB));
      return Metric.KiB;
   end Report_Peak_Memory;

   procedure Enforce_Time
     (Label : String; Observed : Duration; Ceiling : Duration) is
   begin
      if Observed > Ceiling then
         raise Benchmark_Error with
           Label & " performance guardrail exceeded: observed"
           & Duration'Image (Observed) & " ceiling" & Duration'Image (Ceiling);
      end if;
   end Enforce_Time;
end Giflib_Benchmark_Support;
