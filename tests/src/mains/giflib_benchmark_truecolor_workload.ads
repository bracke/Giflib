package Giflib_Benchmark_Truecolor_Workload is
   type Workload_Mode is
     (Generated, Fixed, Fixed_Repeated, Fixed_Phased, Dithered,
      Exact_RGBA_Mixed, Fixed_RGBA_Opaque, Dithered_RGBA_Mixed);
   procedure Run (Mode : Workload_Mode; Enforce : Boolean);
end Giflib_Benchmark_Truecolor_Workload;
