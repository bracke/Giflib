with Giflib_Benchmark_Animation_Workload;
with Giflib_Benchmark_File_Workload;
with Giflib_Benchmark_LZW_Workload;
with Giflib_Benchmark_Optimization_Workload;
with Giflib_Benchmark_Truecolor_Workload;

package body Giflib_Benchmark_Workloads is
   procedure Run_File (Path : String; Enforce : Boolean) is
   begin
      Giflib_Benchmark_File_Workload.Run (Path, Enforce);
   end Run_File;

   procedure Run_Raw_Truecolor (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Generated, Enforce);
   end Run_Raw_Truecolor;

   procedure Run_Fixed_Truecolor (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Fixed, Enforce);
   end Run_Fixed_Truecolor;

   procedure Run_Fixed_Repeated (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Fixed_Repeated, Enforce);
   end Run_Fixed_Repeated;

   procedure Run_Fixed_Phased (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Fixed_Phased, Enforce);
   end Run_Fixed_Phased;

   procedure Run_Dithered_Truecolor (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Dithered, Enforce);
   end Run_Dithered_Truecolor;

   procedure Run_Exact_Alpha (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Exact_RGBA_Mixed, Enforce);
   end Run_Exact_Alpha;

   procedure Run_Fixed_Opaque_Alpha (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Fixed_RGBA_Opaque, Enforce);
   end Run_Fixed_Opaque_Alpha;

   procedure Run_Dithered_Alpha (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run
        (Giflib_Benchmark_Truecolor_Workload.Dithered_RGBA_Mixed, Enforce);
   end Run_Dithered_Alpha;

   procedure Run_Indexed_LZW (Enforce : Boolean) is
   begin
      Giflib_Benchmark_LZW_Workload.Run (Enforce);
   end Run_Indexed_LZW;

   procedure Run_Indexed_LZW_Decode (Enforce : Boolean) is
   begin
      Giflib_Benchmark_LZW_Workload.Run_Decode (Enforce);
   end Run_Indexed_LZW_Decode;

   procedure Run_Animation (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Animation_Workload.Run (Enforce);
   end Run_Animation;

   procedure Run_Optimization (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Optimization_Workload.Run (Enforce);
   end Run_Optimization;
end Giflib_Benchmark_Workloads;
