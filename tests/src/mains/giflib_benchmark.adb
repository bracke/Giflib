with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;

with Giflib_Benchmark_Support;
with Giflib_Benchmark_Workloads;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Giflib_Benchmark is
   function Active_Profile return String is
      Executable : constant String :=
        Project_Tools.Processes.Locate_Command
          (Ada.Command_Line.Command_Name);
      Directory : constant String :=
        (if Executable = ""
         then ""
         else Ada.Directories.Simple_Name
           (Ada.Directories.Containing_Directory
              (Ada.Directories.Full_Name (Executable))));
   begin
      if Directory = "release" then
         return "release";
      elsif Directory = "validation" then
         return "validation";
      elsif Directory = "bin" then
         return "development";
      else
         return "unknown";
      end if;
   end Active_Profile;

   Profile : constant String := Active_Profile;
   Root : constant String := Giflib_Benchmark_Support.Repository_Root;
   Enforce : Boolean := False;
   Run_Synthetic : Boolean := False;
   Run_Fixed : Boolean := False;
   Run_Fixed_Repeated : Boolean := False;
   Run_Fixed_Phased : Boolean := False;
   Run_Dithered : Boolean := False;
   Run_Exact_Alpha : Boolean := False;
   Run_Fixed_Alpha : Boolean := False;
   Run_Dithered_Alpha : Boolean := False;
   Run_Indexed_LZW : Boolean := False;
   Run_Indexed_LZW_Decode : Boolean := False;
   Run_Animation : Boolean := False;
   Run_Optimization : Boolean := False;
   Ran_Workload : Boolean := False;

   procedure Run_Default (Relative_Path : String) is
      Path : constant String :=
        (if Root = ""
         then Relative_Path
         else Project_Tools.Files.Join (Root, Relative_Path));
   begin
      if not Project_Tools.Files.Exists (Path) then
         raise Giflib_Benchmark_Support.Benchmark_Error with
           "missing benchmark fixture: " & Path;
      end if;
      Giflib_Benchmark_Workloads.Run_File (Path, Enforce);
   end Run_Default;
begin
   Ada.Text_IO.Put_Line
     ("benchmark_samples=" &
      Natural'Image (Giflib_Benchmark_Support.Repeat_Count));
   Ada.Text_IO.Put_Line ("benchmark_profile=" & Profile);
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (I) = "--enforce" then
         Enforce := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-truecolor" then
         Run_Synthetic := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-fixed" then
         Run_Fixed := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-fixed-repeated" then
         Run_Fixed_Repeated := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-fixed-phased" then
         Run_Fixed_Phased := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-dither" then
         Run_Dithered := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-alpha-exact" then
         Run_Exact_Alpha := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-alpha-fixed" then
         Run_Fixed_Alpha := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-alpha-dither" then
         Run_Dithered_Alpha := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-lzw" then
         Run_Indexed_LZW := True;
      elsif Ada.Command_Line.Argument (I) = "--indexed-lzw-decode" then
         Run_Indexed_LZW_Decode := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-animation" then
         Run_Animation := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-optimizer" then
         Run_Optimization := True;
      end if;
   end loop;
   if Enforce and then Profile /= "release" then
      raise Giflib_Benchmark_Support.Benchmark_Error with
        "--enforce requires the release-profile executable " &
        "tests/bin/release/giflib_benchmark";
   end if;

   for I in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Argument : constant String := Ada.Command_Line.Argument (I);
      begin
         if Argument = "--enforce"
           or else Argument = "--synthetic-truecolor"
           or else Argument = "--synthetic-fixed"
           or else Argument = "--synthetic-fixed-repeated"
           or else Argument = "--synthetic-fixed-phased"
           or else Argument = "--synthetic-dither"
           or else Argument = "--synthetic-alpha-exact"
           or else Argument = "--synthetic-alpha-fixed"
           or else Argument = "--synthetic-alpha-dither"
           or else Argument = "--synthetic-lzw"
           or else Argument = "--indexed-lzw-decode"
           or else Argument = "--synthetic-animation"
           or else Argument = "--synthetic-optimizer"
         then
            null;
         elsif Argument'Length > 0 and then Argument (Argument'First) = '-' then
            raise Giflib_Benchmark_Support.Benchmark_Error with
              "unknown benchmark option: " & Argument;
         elsif not Project_Tools.Files.Exists (Argument) then
            raise Giflib_Benchmark_Support.Benchmark_Error with
              "missing benchmark fixture: " & Argument;
         else
            Giflib_Benchmark_Workloads.Run_File (Argument, Enforce);
            Ran_Workload := True;
         end if;
      end;
   end loop;
   if Run_Synthetic then
      Giflib_Benchmark_Workloads.Run_Raw_Truecolor (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Fixed then
      Giflib_Benchmark_Workloads.Run_Fixed_Truecolor (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Fixed_Repeated then
      Giflib_Benchmark_Workloads.Run_Fixed_Repeated (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Fixed_Phased then
      Giflib_Benchmark_Workloads.Run_Fixed_Phased (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Dithered then
      Giflib_Benchmark_Workloads.Run_Dithered_Truecolor (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Exact_Alpha then
      Giflib_Benchmark_Workloads.Run_Exact_Alpha (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Fixed_Alpha then
      Giflib_Benchmark_Workloads.Run_Fixed_Opaque_Alpha (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Dithered_Alpha then
      Giflib_Benchmark_Workloads.Run_Dithered_Alpha (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Indexed_LZW then
      Giflib_Benchmark_Workloads.Run_Indexed_LZW (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Indexed_LZW_Decode then
      Giflib_Benchmark_Workloads.Run_Indexed_LZW_Decode (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Animation then
      Giflib_Benchmark_Workloads.Run_Animation (Enforce);
      Ran_Workload := True;
   end if;
   if Run_Optimization then
      Giflib_Benchmark_Workloads.Run_Optimization (Enforce);
      Ran_Workload := True;
   end if;
   if not Ran_Workload then
      Run_Default ("tests/artifacts/giflib-still.gif");
      Run_Default ("tests/artifacts/giflib-animation.gif");
      Run_Default ("tests/artifacts/giflib-truecolor.gif");
      Giflib_Benchmark_Workloads.Run_Raw_Truecolor (Enforce);
      Giflib_Benchmark_Workloads.Run_Fixed_Truecolor (Enforce);
      Giflib_Benchmark_Workloads.Run_Fixed_Repeated (Enforce);
      Giflib_Benchmark_Workloads.Run_Fixed_Phased (Enforce);
      Giflib_Benchmark_Workloads.Run_Dithered_Truecolor (Enforce);
      Giflib_Benchmark_Workloads.Run_Exact_Alpha (Enforce);
      Giflib_Benchmark_Workloads.Run_Fixed_Opaque_Alpha (Enforce);
      Giflib_Benchmark_Workloads.Run_Dithered_Alpha (Enforce);
      Giflib_Benchmark_Workloads.Run_Indexed_LZW (Enforce);
      Giflib_Benchmark_Workloads.Run_Indexed_LZW_Decode (Enforce);
      Giflib_Benchmark_Workloads.Run_Animation (Enforce);
      Giflib_Benchmark_Workloads.Run_Optimization (Enforce);
   end if;
   declare
      Peak_KiB : constant Natural :=
        Giflib_Benchmark_Support.Report_Peak_Memory;
   begin
      if Enforce
        and then
          (Peak_KiB = 0
           or else Peak_KiB > Giflib_Benchmark_Support.Peak_Memory_Ceiling_KiB)
      then
         raise Giflib_Benchmark_Support.Performance_Guardrail_Error with
           "benchmark peak-memory guardrail exceeded or unavailable";
      end if;
   end;
exception
   when Error : Giflib_Benchmark_Support.Performance_Guardrail_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "giflib_benchmark: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status
           (Giflib_Benchmark_Support.Guardrail_Failure_Status));
   when Error : Giflib_Benchmark_Support.Benchmark_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "giflib_benchmark: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Giflib_Benchmark;
