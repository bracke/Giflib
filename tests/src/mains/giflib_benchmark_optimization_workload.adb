with Ada.Text_IO;

with Giflib;
with Giflib.Frames;
with Giflib.Optimization;
with Giflib.Results;
with Giflib.Streams;
with Giflib_Benchmark_Support;

package body Giflib_Benchmark_Optimization_Workload is
   use Giflib_Benchmark_Support;

   procedure Run (Enforce : Boolean) is
      Canvas_Width : constant := 512;
      Canvas_Height : constant := 512;
      Rectangle_Width : constant := 256;
      Rectangle_Height : constant := 256;
      Canvas_Pixels : constant := Canvas_Width * Canvas_Height;
      Rectangle_Pixels : constant := Rectangle_Width * Rectangle_Height;
      Charged_Pixels : constant := Canvas_Pixels + 3 * Rectangle_Pixels;
      Batch_Iterations : Positive := 1;
      Previous : constant Giflib.Streams.Byte_Array (1 .. Canvas_Pixels) :=
        [others => 0];
      Current : Giflib.Streams.Byte_Array (1 .. Canvas_Pixels) := [others => 0];
      Output : Giflib.Streams.Byte_Array (1 .. Rectangle_Pixels);
      Times : Duration_Array;
      Control : constant Giflib.Frames.Graphic_Control :=
        (Has_Transparency => False, others => <>);
      Workload : constant String := "synthetic-optimizer-512";

      procedure Optimize_Once is
         Item : Giflib.Optimization.Frame_Analysis;
         Outcome : Giflib.Results.Result;
      begin
         Outcome := Giflib.Optimization.Analyze_Indexed
           (Previous, Current, Canvas_Width, Canvas_Height,
            Control, Control, True, Item);
         Require (Outcome, "optimizer analyze", Workload);
         Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
           (Previous, Current, Canvas_Width, Canvas_Height, Item, Output);
         Require (Outcome, "optimizer extract", Workload);
      end Optimize_Once;
   begin
      for Y in 128 .. 383 loop
         for X in 128 .. 383 loop
            if X in 128 | 383 or else Y in 128 | 383 then
               Current (Y * Canvas_Width + X + 1) := 1;
            end if;
         end loop;
      end loop;

      Batch_Iterations := Select_Batch_Iterations
        (Optimize_Once'Access, Workload);

      for Sample in 1 .. Repeat_Count loop
         Times (Sample) :=
           Measure_Batch (Optimize_Once'Access, Batch_Iterations)
           / Batch_Iterations;
      end loop;
      Sort (Times);
      if Enforce then
         declare
            Ceiling : constant Duration := Baseline_Sensitive_Ceiling
              (Workload,
               Batched_Throughput_Ceiling
                 (Long_Float (Charged_Pixels),
                  Optimization_Pixels_Per_Second_Floor,
                  Batch_Iterations),
               Reference => 0.000654);
         begin
            Enforce_Time (Workload, Times (3), Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " charged_pixels=" & Natural'Image (Charged_Pixels)
         & " batch_iterations=" & Positive'Image (Batch_Iterations)
         & " cpu_median_s=" & Duration'Image (Times (3)));
   end Run;
end Giflib_Benchmark_Optimization_Workload;
