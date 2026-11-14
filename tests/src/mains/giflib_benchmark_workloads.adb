with Giflib_Benchmark_File_Workload;
with Giflib_Benchmark_Truecolor_Workload;

package body Giflib_Benchmark_Workloads is
   procedure Run_File (Path : String; Enforce : Boolean) is
   begin
      Giflib_Benchmark_File_Workload.Run (Path, Enforce);
   end Run_File;

   procedure Run_Raw_Truecolor (Enforce : Boolean) is
   begin
      Giflib_Benchmark_Truecolor_Workload.Run (Enforce);
   end Run_Raw_Truecolor;
end Giflib_Benchmark_Workloads;
