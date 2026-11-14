with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Self_Test_Support;

package body Giflib_Tooling.Repository_Race_Support is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Processes renames Project_Tools.Processes;

   procedure With_Fixture
     (Name : String;
      Process : not null access procedure
        (Root : String; Inside : String; Link_Command : String))
   is
      Root : constant String := Fixtures.Fresh_Temp_Dir (Name);
      Inside : constant String := Files.Join (Root, "inside");
      Link_Command : constant String := Processes.Locate_Command ("ln");
   begin
      Fixtures.Make_Directory (Inside);
      Fixtures.Write_Text_File (Files.Join (Root, "outside.txt"), "outside");
      Process (Root, Inside, Link_Command);
      Fixtures.Cleanup (Root);
   exception
      when others =>
         Fixtures.Cleanup (Root);
         raise;
   end With_Fixture;

   procedure Create_Link
     (Directory : String;
      Link_Command : String;
      Target : String;
      Name : String) is
   begin
      Check.Check
        (Processes.Run_Status
           ("create repository symlink", Directory, Link_Command,
            Processes.Arguments
              ([Processes.Argument ("-s"),
                Processes.Argument (Target),
                Processes.Argument (Name)]),
            Quiet => True) = 0,
         "symlink regression fixture can be created");
   end Create_Link;
end Giflib_Tooling.Repository_Race_Support;
