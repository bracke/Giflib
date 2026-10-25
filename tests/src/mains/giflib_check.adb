with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Project_Tools.Alire_Manifests;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;

procedure Giflib_Check is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   Root : constant String :=
     Files.Find_Root_Upward (Ada.Directories.Current_Directory, "giflib.gpr");
   Tests_Bin : constant String := Files.Join (Root, "tests/bin");
   Release_Tests_Bin : constant String := Files.Join (Tests_Bin, "release");
   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "all"
      else Ada.Command_Line.Argument (1));
   Alr : constant String := Processes.Locate_Command ("alr");
   Gprbuild : constant String := Processes.Locate_Command ("gprbuild");
   Checks : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (Root);

   procedure Validate_Tooling is
   begin
      Project_Tools.Release_Checks.Require_Text
        (Checks, "alire.toml", "gnat_native = ""^15""", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/alire.toml", "gnat_native = ""^15""", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "giflib.gpr", "with ""giflib_build.gpr"";", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/giflib_whitebox.gpr",
         "with ""../giflib_build.gpr"";",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/public_api.gpr",
         "with ""../giflib.gpr"";",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/unit_tests.gpr",
         "with ""giflib_whitebox.gpr"";",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/tools.gpr",
         "with ""../giflib.gpr"";",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/check_private_api.sh",
         "private child unit",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/alire.toml",
         "executables = [""giflib_tests""]",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks,
         "tests/alire.toml",
         "project-files = [""unit_tests.gpr""]",
         Quiet => False);
      Project_Tools.Alire_Manifests.Require_Workspace_Pin
        (Files.Join (Root, "tests/alire.toml"),
         "project_tools",
         "../../project_tools",
         Quiet => False);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File       => Files.Join (Root, "tests/unit_tests.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory   => Files.Join (Root, "tests/src/mains"),
         Quiet              => False);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File       => Files.Join (Root, "tests/tools.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory   => Files.Join (Root, "tests/src/mains"),
         Quiet              => False);
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir             => Files.Join (Root, "tests/src"),
         Spec_Pattern         => "giflib-testing-test_*.ads",
         Suite_Path           => Files.Join (Root, "tests/src/giflib-testing-suite.adb"),
         Suite_Add_Prefix     => "new ",
         Suite_Add_Suffix     => ".Test",
         Required_Stem_Suffix => "",
         Quiet                => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_tests.adb", "with Project_Tools.", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_check.adb", "with Project_Tools.", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_samples.adb", "with Project_Tools.",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_fixtures.adb", "with Project_Tools.",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_external_checks.adb", "with Project_Tools.",
         Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_benchmark.adb", "with Project_Tools.", Quiet => False);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_fuzz.adb", "with Project_Tools.", Quiet => False);
   exception
      when Program_Error =>
         Project_Tools.Release_Checks.Fail
           ("giflib_check: project_tools integration validation failed");
   end Validate_Tooling;

   procedure Run_Tool
     (Name  : String;
      Args  : Processes.Argument_Vectors.Vector;
      Label : String;
      Bin_Directory : String := Tests_Bin)
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
      Bin_Directory : String := Tests_Bin)
   is
      procedure Run_Case (Relative_Path : String; Label : String) is
      begin
         if Enforce then
            Run_Tool
              ("giflib_benchmark",
               Processes.Arguments
                 ([Processes.Argument ("--enforce"),
                   Processes.Argument (Files.Join (Root, Relative_Path))]),
               Label,
               Bin_Directory);
         else
            Run_Tool
              ("giflib_benchmark",
               Processes.Arguments
                 ([Processes.Argument (Files.Join (Root, Relative_Path))]),
               Label,
               Bin_Directory);
         end if;
      end Run_Case;
   begin
      Run_Case ("tests/fixtures/external/docbook-tip.gif", "benchmark docbook tip");
      Run_Case
        ("tests/fixtures/external/docbook-warning.gif", "benchmark docbook warning");
      Run_Case
        ("tests/fixtures/generated/imagemagick-indexed.gif", "benchmark indexed fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-animation.gif", "benchmark animation fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-interlaced.gif", "benchmark interlaced fixture");
      Run_Case
        ("tests/fixtures/generated/imagemagick-benchmark-512.gif", "benchmark GIF fixture");
      if Enforce then
         Run_Tool
           ("giflib_benchmark",
            Processes.Arguments
              ([Processes.Argument ("--enforce"),
                Processes.Argument ("--synthetic-truecolor")]),
            "benchmark raw truecolor quantization",
            Bin_Directory);
      else
         Run_Tool
           ("giflib_benchmark",
            Processes.Arguments
              ([Processes.Argument ("--synthetic-truecolor")]),
            "benchmark raw truecolor quantization",
            Bin_Directory);
      end if;
   end Run_Benchmarks;

   procedure External
     (Include_Benchmarks : Boolean := True;
      Bin_Directory      : String := Tests_Bin;
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
     (Bin_Directory : String := Tests_Bin;
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
