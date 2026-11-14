with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;

with Giflib_Benchmark_Support;
with Giflib_Benchmark_Workloads;
with Project_Tools.Files;

procedure Giflib_Benchmark is
   Enforce : Boolean := False;
   Run_Synthetic : Boolean := False;
   Ran_Workload : Boolean := False;

   procedure Run_Default (Path : String) is
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
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (I) = "--enforce" then
         Enforce := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-truecolor" then
         Run_Synthetic := True;
      end if;
   end loop;

   for I in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Argument : constant String := Ada.Command_Line.Argument (I);
      begin
         if Argument = "--enforce" or else Argument = "--synthetic-truecolor" then
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
   if not Ran_Workload then
      Run_Default ("artifacts/giflib-still.gif");
      Run_Default ("artifacts/giflib-animation.gif");
      Run_Default ("artifacts/giflib-truecolor.gif");
      Giflib_Benchmark_Workloads.Run_Raw_Truecolor (Enforce);
   end if;
   declare
      Peak_KiB : constant Natural :=
        Giflib_Benchmark_Support.Report_Peak_Memory;
   begin
      if Enforce and then (Peak_KiB = 0 or else Peak_KiB > 65_536) then
         raise Giflib_Benchmark_Support.Benchmark_Error with
           "benchmark peak-memory guardrail exceeded or unavailable";
      end if;
   end;
exception
   when Error : Giflib_Benchmark_Support.Benchmark_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "giflib_benchmark: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Giflib_Benchmark;
