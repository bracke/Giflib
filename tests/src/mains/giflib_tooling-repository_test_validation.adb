with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Text;

with Giflib_Tooling.Ada_Context_Clauses;
with Giflib_Tooling.Repository_Validation_Support;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Suite_Registrations;
with Giflib_Tooling.Suite_Routine_Analysis;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Repository_Test_Validation is
   package Context_Clauses renames Giflib_Tooling.Ada_Context_Clauses;
   package Files renames Project_Tools.Files;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Support renames Giflib_Tooling.Repository_Validation_Support;
   package Registrations renames Giflib_Tooling.Suite_Registrations;
   use type Registrations.Registration_Issue;
   package Routines renames Giflib_Tooling.Suite_Routine_Analysis;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_Type => String);

   procedure Require_Registered_Test_Packages
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Test_Directory : String;
      Suite_Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Root : constant String := Snapshots.Root (Repository);
      Suite_Withs : Syntax.Name_Vectors.Vector;
      Inventory : Registrations.Registration_Inventory;
      procedure Load_Suite
        (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
      begin
         Suite_Withs := Context_Clauses.Units (Parsed);
         Inventory := Registrations.Registrations (Parsed, Budget);
      end Load_Suite;
      Discovered_Units : Name_Sets.Set;
      Absolute_Test_Directory : constant String :=
        Ada.Directories.Full_Name (Files.Join (Root, Test_Directory));

      procedure Inspect (Path : String; Name : String) is
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
         Lower_Name : constant String := Text_Case.Lower (Name);
         Is_Spec : constant Boolean :=
           Project_Tools.Text.Starts_With
             (Lower_Name, "giflib-testing-test_")
           and then Project_Tools.Text.Ends_With (Lower_Name, ".ads");
         Is_Body : constant Boolean :=
           Project_Tools.Text.Starts_With
             (Lower_Name, "giflib-testing-test_")
           and then Project_Tools.Text.Ends_With (Lower_Name, ".adb");
      begin
         if Parent /= Absolute_Test_Directory
           or else not (Is_Spec or Is_Body)
         then
            return;
         end if;
         declare
            Other_Suffix : constant String :=
              (if Is_Spec then ".adb" else ".ads");
            Other_Path : constant String :=
              Files.Join (Test_Directory, Support.Stem (Name) & Other_Suffix);
         begin
            if not Snapshots.Contains (Repository, Other_Path) then
               Fail
                 ((if Is_Spec then "AUnit test package spec has no body: "
                   else "AUnit test package body has no spec: ") & Name);
            end if;
            if Is_Spec then
               declare
                  Unit_Name : constant String := Support.Package_Name (Name);
                  Registers : Boolean := False;
                  procedure Check_Body
                    (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
                  begin
                     Registers := Routines.Registers_Test_Routine
                       (Parsed, Budget);
                  end Check_Body;
               begin
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Budget,
                     Giflib_Tooling.Repository_Source_Cache.Source_Length
                       (Cached_Sources, Other_Path));
                  Giflib_Tooling.Repository_Source_Cache.Inspect
                    (Cached_Sources, Other_Path, Check_Body'Access);
                  Discovered_Units.Include (Unit_Name);
                  if not Registers then
                     Fail
                       ("AUnit test package registers no routines: " &
                        Support.Stem (Name));
                  elsif not Syntax.Contains (Suite_Withs, Unit_Name) then
                     Fail
                       ("AUnit test package is not withed by suite: " &
                        Unit_Name);
                  elsif not Syntax.Contains
                    (Inventory.Units, Unit_Name)
                  then
                     Fail
                       ("AUnit test package is not added to suite: " &
                        Unit_Name);
                  end if;
               end;
            end if;
         end;
      end Inspect;
   begin
      Giflib_Tooling.Work_Budgets.Charge_Scan
        (Budget,
         Giflib_Tooling.Repository_Source_Cache.Source_Length
           (Cached_Sources, Suite_Path));
      Giflib_Tooling.Repository_Source_Cache.Inspect
        (Cached_Sources, Suite_Path, Load_Suite'Access);
      if Inventory.Issue /= Registrations.No_Registration_Issue then
         Fail
           ("AUnit suite registration structure is invalid: " &
            Registrations.Registration_Issue'Image (Inventory.Issue));
      elsif Ada.Strings.Unbounded.Length (Inventory.Duplicate) > 0 then
         Fail
           ("AUnit test package is added to suite more than once: " &
            Ada.Strings.Unbounded.To_String (Inventory.Duplicate));
      end if;
      Snapshots.Walk
        (Repository, Absolute_Test_Directory, Inspect'Access);
      for Item of Inventory.Units loop
         declare
            Unit_Name : constant String :=
              Ada.Strings.Unbounded.To_String (Item);
         begin
            if not Discovered_Units.Contains (Unit_Name) then
               Fail
                 ("AUnit suite adds an unknown test package: " & Unit_Name);
            end if;
         end;
      end loop;
   end Require_Registered_Test_Packages;
end Giflib_Tooling.Repository_Test_Validation;
