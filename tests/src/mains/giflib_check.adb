with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Giflib_Benchmark_Support;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;

procedure Giflib_Check is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   Root : constant String :=
     Files.Find_Root_Upward (Ada.Directories.Current_Directory, "giflib.gpr");
   Development_Tests_Bin : constant String := Files.Join (Root, "tests/bin");
   function Active_Binary_Directory return String is
      Executable : constant String :=
        Processes.Locate_Command (Ada.Command_Line.Command_Name);
   begin
      if Executable = "" then
         Project_Tools.Release_Checks.Fail
           ("giflib_check: cannot locate its executable on PATH");
      end if;
      return Ada.Directories.Containing_Directory
        (Ada.Directories.Full_Name (Executable));
   end Active_Binary_Directory;
   Active_Tests_Bin : constant String := Active_Binary_Directory;
   Release_Tests_Bin : constant String :=
     Files.Join (Development_Tests_Bin, "release");
   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "all"
      else Ada.Command_Line.Argument (1));
   Alr : constant String := Processes.Locate_Command ("alr");
   Gprbuild : constant String := Processes.Locate_Command ("gprbuild");

   procedure Run_Tool
     (Name  : String;
      Args  : Processes.Argument_Vectors.Vector;
      Label : String;
      Bin_Directory : String := Active_Tests_Bin);

   procedure Validate_Tooling
     (Bin_Directory : String := Active_Tests_Bin) is
   begin
      Run_Tool
        ("giflib_tooling_tests", Processes.No_Arguments,
         "tooling mutation tests", Bin_Directory);
      Run_Tool
        ("giflib_tooling_probe",
         Processes.Arguments ([Processes.Argument (Root)]),
         "tooling structure validation", Bin_Directory);
   end Validate_Tooling;

   procedure Run_Tool
     (Name  : String;
      Args  : Processes.Argument_Vectors.Vector;
      Label : String;
      Bin_Directory : String := Active_Tests_Bin)
   is
   begin
      Processes.Run
        (Label,
         Root,
         Files.Join (Bin_Directory, Name),
         Args);
   end Run_Tool;

   procedure Run_Alire
     (Args  : Processes.Argument_Vectors.Vector;
      Label : String)
   is
   begin
      Processes.Run (Label, Root, Alr, Args);
   end Run_Alire;

   procedure Run_Benchmarks
     (Enforce : Boolean := False;
      Bin_Directory : String := Active_Tests_Bin)
   is
      procedure Run_Benchmark
        (Args : Processes.Argument_Vectors.Vector;
         Label : String)
      is
         Program : constant String := Files.Join
           (Bin_Directory, "giflib_benchmark");
         Status : Integer;
      begin
         if not Enforce then
            Run_Tool ("giflib_benchmark", Args, Label, Bin_Directory);
            return;
         end if;
         Status := Processes.Run_Status (Label, Root, Program, Args);
         if Status = Giflib_Benchmark_Support.Guardrail_Failure_Status then
            Ada.Text_IO.Put_Line
              ("retrying transient benchmark guardrail in a fresh process");
            Status := Processes.Run_Status
              (Label & " retry", Root, Program, Args);
         end if;
         if Status /= 0 then
            Project_Tools.Release_Checks.Fail
              (Label & " failed with status" & Integer'Image (Status));
         end if;
      end Run_Benchmark;

      procedure Run_Case (Relative_Path : String; Label : String) is
      begin
         if Enforce then
            Run_Benchmark
              (Processes.Arguments
                 ([Processes.Argument ("--enforce"),
                   Processes.Argument (Files.Join (Root, Relative_Path))]),
               Label);
         else
            Run_Benchmark
              (Processes.Arguments
                 ([Processes.Argument (Files.Join (Root, Relative_Path))]),
               Label);
         end if;
      end Run_Case;

      procedure Run_Option (Option : String; Label : String) is
      begin
         Run_Benchmark
           ((if Enforce
             then Processes.Arguments
               ([Processes.Argument ("--enforce"),
                 Processes.Argument (Option)])
             else Processes.Arguments ([Processes.Argument (Option)])),
            Label);
      end Run_Option;
   begin
      Run_Case ("tests/fixtures/external/docbook-tip.gif", "benchmark docbook tip");
      Run_Case
        ("tests/fixtures/external/docbook-warning.gif", "benchmark docbook warning");
      Run_Case
        ("tests/fixtures/generated/imagemagick-indexed.gif", "benchmark indexed fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-animation.gif", "benchmark animation fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-benchmark-animation-256.gif",
         "benchmark large composited animation fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-interlaced.gif", "benchmark interlaced fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-benchmark-512.gif", "benchmark GIF fixture");
      Run_Option
        ("--synthetic-truecolor", "benchmark raw truecolor quantization");
      Run_Option
        ("--synthetic-fixed", "benchmark fixed-palette quantization");
      Run_Option
        ("--synthetic-fixed-repeated",
         "benchmark cache-friendly fixed-palette quantization");
      Run_Option
        ("--synthetic-fixed-phased",
         "benchmark phase-changing fixed-palette quantization");
      Run_Option
        ("--synthetic-dither", "benchmark dithered quantization");
      Run_Option
        ("--synthetic-alpha-exact", "benchmark exact mixed-alpha quantization");
      Run_Option
        ("--synthetic-alpha-fixed", "benchmark opaque RGBA fixed quantization");
      Run_Option
        ("--synthetic-alpha-dither", "benchmark mixed-alpha dithering");
      Run_Option
        ("--synthetic-lzw", "benchmark indexed LZW encoding");
      Run_Option
        ("--indexed-lzw-decode", "benchmark indexed LZW decoding");
      Run_Option
        ("--synthetic-animation", "benchmark animation workspace reuse");
      Run_Option
        ("--synthetic-optimizer", "benchmark frame optimization");
   end Run_Benchmarks;

   procedure External
     (Include_Benchmarks : Boolean := True;
      Bin_Directory      : String := Active_Tests_Bin;
      Label_Prefix       : String := "")
   is
   begin
      Run_Tool
        ("giflib_generate_samples",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/artifacts"))]),
         Label_Prefix & "giflib sample generation",
         Bin_Directory);
      Run_Tool
        ("giflib_generate_fixtures",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/fixtures/generated"))]),
         Label_Prefix & "independent fixture generation",
         Bin_Directory);
      Run_Tool
        ("giflib_external_checks",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/artifacts"))]),
         Label_Prefix & "external oracle checks",
         Bin_Directory);
      if Include_Benchmarks then
         Run_Benchmarks (Bin_Directory => Bin_Directory);
      end if;
   end External;

   procedure Run_Correctness_Checks
     (Bin_Directory : String := Active_Tests_Bin;
      Label_Prefix  : String := "")
   is
   begin
      Run_Tool
        ("giflib_tests",
         Processes.No_Arguments,
         Label_Prefix & "AUnit suite",
         Bin_Directory);
      Run_Tool
        ("giflib_fuzz",
         Processes.Arguments
           ([Processes.Argument ("10000"), Processes.Argument ("3235823838")]),
         Label_Prefix & "deterministic fuzz harness",
         Bin_Directory);
      External
        (Include_Benchmarks => False,
         Bin_Directory      => Bin_Directory,
         Label_Prefix       => Label_Prefix);
   end Run_Correctness_Checks;

   procedure All_Checks is
   begin
      Run_Correctness_Checks;
      Run_Benchmarks;
   end All_Checks;
begin
   if Root = "" then
      Project_Tools.Release_Checks.Fail
        ("giflib_check: run from within the giflib source tree");
   elsif Ada.Command_Line.Argument_Count > 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_check [all|external|fixtures|tooling|release]");
   elsif Command = "tooling" then
      Validate_Tooling;
   elsif Command = "fixtures" then
      Run_Tool
        ("giflib_generate_fixtures",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/fixtures/generated"))]),
         "independent fixture generation");
   elsif Command = "external" then
      External;
   elsif Command = "all" then
      All_Checks;
   elsif Command = "release" then
      Processes.Require_Command ("alr", "giflib_check: alr is required");
      Validate_Tooling;
      Run_Alire (Processes.Arguments ([Processes.Argument ("build")]), "root Alire build");
      Run_Alire
        (Processes.Arguments
           ([Processes.Argument ("--chdir"), Processes.Argument ("tests"),
             Processes.Argument ("build")]),
         "test Alire build");
      Run_Alire
        (Processes.Arguments
           ([Processes.Argument ("exec"), Processes.Argument ("--"),
             Processes.Argument ("gprbuild"), Processes.Argument ("-P"),
             Processes.Argument ("examples/examples.gpr"), Processes.Argument ("-p"),
             Processes.Argument ("-j0")]),
         "example build");
      Run_Correctness_Checks;
      Processes.Run
        ("release-profile unit-test build",
         Root,
         Gprbuild,
         Processes.Arguments
           ([Processes.Argument ("-P"),
             Processes.Argument (Files.Join (Root, "tests/unit_tests.gpr")),
             Processes.Argument ("-p"), Processes.Argument ("-j0"),
             Processes.Argument
               ("-XGIFLIB_BUILD_PROFILE_OVERRIDE=release")]));
      Processes.Run
        ("release-profile tools build",
         Root,
         Gprbuild,
         Processes.Arguments
           ([Processes.Argument ("-P"),
             Processes.Argument (Files.Join (Root, "tests/tools.gpr")),
             Processes.Argument ("-p"), Processes.Argument ("-j0"),
             Processes.Argument
               ("-XGIFLIB_BUILD_PROFILE_OVERRIDE=release")]));
      Validate_Tooling (Release_Tests_Bin);
      Run_Correctness_Checks
        (Bin_Directory => Release_Tests_Bin,
         Label_Prefix  => "release-profile ");
      Run_Benchmarks
        (Enforce => True,
         Bin_Directory => Release_Tests_Bin);
      Run_Alire
        (Processes.Arguments
           ([Processes.Argument ("exec"), Processes.Argument ("--"),
             Processes.Argument ("gnatprove"), Processes.Argument ("-P"),
             Processes.Argument ("giflib.gpr"), Processes.Argument ("--level=2"),
             Processes.Argument ("--prover=cvc5"),
             Processes.Argument ("--report=all"),
             Processes.Argument ("-j1")]),
         "SPARK proof");
      Run_Alire
        (Processes.Arguments
           ([Processes.Argument ("show"), Processes.Argument ("--solve")]),
         "Alire solution check");
   else
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_check [all|external|fixtures|tooling|release]");
   end if;
   Ada.Text_IO.Put_Line ("Ada check command completed: " & Command);
end Giflib_Check;
