with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Project_Tools.Alire_Manifests;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;

procedure Giflib_Check is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   Root : constant String :=
     Files.Find_Root_Upward (Ada.Directories.Current_Directory, "giflib.gpr");
   Tests_Bin : constant String := Files.Join (Root, "tests/bin");
   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "all"
      else Ada.Command_Line.Argument (1));
   Alr : constant String := Processes.Locate_Command ("alr");
   Checks : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (Root);

   procedure Validate_Tooling is
   begin
      Project_Tools.Alire_Manifests.Require_Workspace_Pin
        (Files.Join (Root, "tests/alire.toml"),
         "project_tools",
         "../../project_tools",
         Quiet => True);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File       => Files.Join (Root, "tests/tests.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory   => Files.Join (Root, "tests/src/mains"),
         Quiet              => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_tests.adb", "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_check.adb", "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_samples.adb", "with Project_Tools.",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_fixtures.adb", "with Project_Tools.",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_external_checks.adb", "with Project_Tools.",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_benchmark.adb", "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_fuzz.adb", "with Project_Tools.", Quiet => True);
   exception
      when Program_Error =>
         Project_Tools.Release_Checks.Fail
           ("giflib_check: project_tools integration validation failed");
   end Validate_Tooling;

   procedure Run_Tool
     (Name  : String;
      Args  : Processes.Argument_Vectors.Vector;
      Label : String)
   is
   begin
      Processes.Run
        (Label,
         Root,
         Files.Join (Tests_Bin, Name),
         Args);
   end Run_Tool;

   procedure Run_Alire
     (Args  : Processes.Argument_Vectors.Vector;
      Label : String)
   is
   begin
      Processes.Run (Label, Root, Alr, Args);
   end Run_Alire;

   procedure External is
   begin
      Run_Tool
        ("giflib_generate_samples",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/artifacts"))]),
         "giflib sample generation");
      Run_Tool
        ("giflib_generate_fixtures",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/fixtures/generated"))]),
         "independent fixture generation");
      Run_Tool
        ("giflib_external_checks",
         Processes.Arguments
           ([Processes.Argument (Files.Join (Root, "tests/artifacts"))]),
         "external oracle checks");
      Run_Tool
        ("giflib_benchmark",
         Processes.Arguments
           ([Processes.Argument
               (Files.Join (Root, "tests/fixtures/external/docbook-tip.gif")),
             Processes.Argument
               (Files.Join (Root, "tests/fixtures/external/docbook-warning.gif")),
             Processes.Argument
               (Files.Join (Root, "tests/fixtures/generated/imagemagick-indexed.gif")),
             Processes.Argument
               (Files.Join (Root, "tests/fixtures/generated/imagemagick-animation.gif")),
             Processes.Argument
               (Files.Join (Root, "tests/fixtures/generated/imagemagick-interlaced.gif"))]),
         "independent corpus decode/encode benchmark");
   end External;

   procedure All_Checks is
   begin
      Run_Tool ("giflib_tests", Processes.No_Arguments, "AUnit suite");
      Run_Tool
        ("giflib_fuzz",
         Processes.Arguments
           ([Processes.Argument ("10000"), Processes.Argument ("3235823838")]),
         "deterministic fuzz harness");
      External;
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
      All_Checks;
      Run_Alire
        (Processes.Arguments
           ([Processes.Argument ("exec"), Processes.Argument ("--"),
             Processes.Argument ("gnatprove"), Processes.Argument ("-P"),
             Processes.Argument ("giflib.gpr"), Processes.Argument ("-u"),
             Processes.Argument ("giflib-internal-interlacing.adb"),
             Processes.Argument ("--mode=flow"), Processes.Argument ("--report=all"),
             Processes.Argument ("-j1")]),
         "SPARK flow analysis");
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
