package Giflib_Benchmark_Workloads is
   procedure Run_File (Path : String; Enforce : Boolean);
   procedure Run_Raw_Truecolor (Enforce : Boolean);
   procedure Run_Fixed_Truecolor (Enforce : Boolean);
   procedure Run_Fixed_Repeated (Enforce : Boolean);
   procedure Run_Fixed_Phased (Enforce : Boolean);
   procedure Run_Dithered_Truecolor (Enforce : Boolean);
   procedure Run_Exact_Alpha (Enforce : Boolean);
   procedure Run_Fixed_Opaque_Alpha (Enforce : Boolean);
   procedure Run_Dithered_Alpha (Enforce : Boolean);
   procedure Run_Indexed_LZW (Enforce : Boolean);
   procedure Run_Indexed_LZW_Decode (Enforce : Boolean);
   procedure Run_Animation (Enforce : Boolean);
   procedure Run_Optimization (Enforce : Boolean);
end Giflib_Benchmark_Workloads;
