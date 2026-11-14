with Ada.Directories;

with Project_Tools.Files;
with Project_Tools.Text;

with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Token_Patterns;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Architecture_Layout is
   package Files renames Project_Tools.Files;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Patterns renames Giflib_Tooling.Token_Patterns;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;

   function Line_Count (Text : String) return Natural is
      Result : Natural := (if Text = "" then 0 else 1);
   begin
      for Index in Text'Range loop
         if Text (Index) = ASCII.LF and then Index < Text'Last then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Line_Count;

   procedure Validate
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Root : constant String := Snapshots.Root (Repository);
      Test_Root : constant String := Ada.Directories.Full_Name
        (Files.Join (Root, "tests/src"));
      Subunit_Root : constant String := Files.Join (Test_Root, "subunits");
      Tooling_Subunit_Root : constant String :=
        Files.Join (Test_Root, "tooling_subunits");
      Main_Root : constant String := Files.Join (Test_Root, "mains");
      Test_Main_Root : constant String := Files.Join (Test_Root, "test_mains");
      procedure Inspect (Path : String; Name : String) is
      begin
         if Source_Names.Is_Ada_Source (Name) then
            declare
               Parent : constant String :=
                 Ada.Directories.Containing_Directory (Path);
               procedure Check_Text (Text : String) is
                  Has_Separate : Boolean := False;
                  procedure Check_Syntax
                    (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
                  begin
                     Has_Separate := Patterns.Contains_Code
                       (Parsed, "separate (");
                  end Check_Syntax;
               begin
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Budget, Text'Length);
                  Giflib_Tooling.Repository_Source_Cache.Inspect
                    (Cached_Sources, Path, Check_Syntax'Access);
                  if Parent /= Subunit_Root
                    and then Parent /= Tooling_Subunit_Root
                    and then Has_Separate
                  then
                     Fail
                       ("test subunit is outside an approved directory: " & Name);
                  elsif Parent in Subunit_Root | Tooling_Subunit_Root then
                     if Parent = Tooling_Subunit_Root
                       and then not Project_Tools.Text.Starts_With
                         (Text_Case.Lower (Name), "giflib_tooling-")
                     then
                        Fail ("non-tooling unit is in tooling_subunits: " & Name);
                     elsif not Has_Separate then
                        Fail
                          ((if Parent = Tooling_Subunit_Root
                            then "non-subunit is in tooling_subunits: "
                            else "non-subunit is in subunits: ") & Name);
                     elsif Parent = Tooling_Subunit_Root
                       and then Line_Count (Text) > 500
                     then
                        Fail ("tooling subunit exceeds 500 lines: " & Name);
                     end if;
                  elsif Parent not in Test_Root | Subunit_Root | Main_Root |
                    Test_Main_Root
                  then
                     Fail ("test source is outside an approved directory: " & Name);
                  elsif
                    ((Parent = Test_Root
                      and then Project_Tools.Text.Starts_With
                        (Text_Case.Lower (Name), "giflib-testing-test_"))
                     or else Parent in Main_Root | Test_Main_Root)
                    and then Line_Count (Text) > 500
                  then
                     Fail ("test or tooling source exceeds 500 lines: " & Name);
                  end if;
               end Check_Text;
            begin
               Snapshots.Inspect_Text (Repository, Path, Check_Text'Access);
            end;
         end if;
      end Inspect;
   begin
      Snapshots.Walk (Repository, "tests/src", Inspect'Access);
   end Validate;
end Giflib_Tooling.Architecture_Layout;
