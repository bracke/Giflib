with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Text;

with Giflib_Tooling.GPR_Analysis;
with Giflib_Tooling.Repository_Analysis;
with Giflib_Tooling.Repository_Validation_Support;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Repository_Project_Validation is
   package Analysis renames Giflib_Tooling.Repository_Analysis;
   package GPR renames Giflib_Tooling.GPR_Analysis;
   package Files renames Project_Tools.Files;
   package Inventory renames Giflib_Tooling.Validation_Plans;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Source_Caches renames Giflib_Tooling.Repository_Source_Cache;
   package Support renames Giflib_Tooling.Repository_Validation_Support;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_Type => String);

   type Analyzed_Project is record
      Project_Path : Ada.Strings.Unbounded.Unbounded_String;
      Source_Directory : Ada.Strings.Unbounded.Unbounded_String;
      Mains : Syntax.Name_Vectors.Vector;
      Main_Names : Name_Sets.Set;
      Discovered : Name_Sets.Set;
      Declared_Mains : Name_Sets.Set;
   end record;

   function Load_Project
     (Repository : Snapshots.Snapshot;
      Project : Inventory.Project_Inventory;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Analyzed_Project
   is
      Result : Analyzed_Project :=
        (Project_Path => Project.Project_Path,
         Source_Directory => Project.Source_Directory,
         others => <>);
      Project_Path : constant String :=
        Ada.Strings.Unbounded.To_String (Project.Project_Path);
   begin
      declare
         procedure Load (Text : String) is
         begin
            Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
            Result.Mains := GPR.Attribute_Strings (Text, "Main");
         end Load;
      begin
         Support.Inspect_File (Repository, Project_Path, Load'Access);
      end;
      if Result.Mains.Is_Empty then
         Fail (Project_Path & " has no exact Main attribute");
      end if;
      for Item of Result.Mains loop
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Item);
            Key : constant String := Text_Case.Lower (Name);
         begin
            if Name'Length < 5
              or else not Project_Tools.Text.Ends_With (Key, ".adb")
            then
               Fail (Project_Path & " has a non-Ada main entry");
            elsif Result.Main_Names.Contains (Key) then
               Fail (Project_Path & " lists duplicate main source: " & Name);
            end if;
            Result.Main_Names.Insert (Key);
         end;
      end loop;
      return Result;
   end Load_Project;

   procedure Scan_Project_Sources
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Source_Caches.Cache;
      Project : in out Analyzed_Project;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Root : constant String := Snapshots.Root (Repository);
      Source_Directory : constant String :=
        Ada.Strings.Unbounded.To_String (Project.Source_Directory);
      Absolute_Source_Directory : constant String :=
        Ada.Directories.Full_Name (Files.Join (Root, Source_Directory));

      procedure Inspect_Source (Path : String; Name : String) is
         Key : constant String := Text_Case.Lower (Name);
      begin
         if Ada.Directories.Containing_Directory (Path) =
           Absolute_Source_Directory
           and then Name'Length > 4
           and then Project_Tools.Text.Ends_With (Key, ".adb")
         then
            Project.Discovered.Include (Key);
            declare
               procedure Inspect (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
               begin
                  if Analysis.Declares_Main
                    (Parsed, Support.Stem (Name), Budget)
                  then
                     Project.Declared_Mains.Include (Key);
                  end if;
               end Inspect;
            begin
               Source_Caches.Inspect (Cached_Sources, Path, Inspect'Access);
            end;
         end if;
      end Inspect_Source;
   begin
      Snapshots.Walk
        (Repository, Absolute_Source_Directory, Inspect_Source'Access);
   end Scan_Project_Sources;

   procedure Validate_Project_Sources (Project : Analyzed_Project) is
      Project_Path : constant String :=
        Ada.Strings.Unbounded.To_String (Project.Project_Path);
   begin
      for Name of Project.Declared_Mains loop
         if not Project.Main_Names.Contains (Name) then
            Fail (Project_Path & " does not list main source: " & Name);
         end if;
      end loop;
      for Item of Project.Mains loop
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Item);
            Key : constant String := Text_Case.Lower (Name);
         begin
            if not Project.Discovered.Contains (Key) then
               Fail (Project_Path & " lists missing main source: " & Name);
            elsif not Project.Declared_Mains.Contains (Key) then
               Fail
                 (Project_Path &
                  " main entry does not declare its procedure: " & Name);
            end if;
         end;
      end loop;
   end Validate_Project_Sources;

   procedure Include_Executables
     (Project : Analyzed_Project; Expected : in out Name_Sets.Set) is
   begin
      for Item of Project.Mains loop
         declare
            Executable : constant String :=
              Support.Stem (Ada.Strings.Unbounded.To_String (Item));
         begin
            if Expected.Contains (Executable) then
               Fail
                 ("executable is declared by more than one project: " &
                  Executable);
            end if;
            Expected.Insert (Executable);
         end;
      end loop;
   end Include_Executables;

   function Read_Documented_Executables
     (Repository : Snapshots.Snapshot;
      Documentation_Path : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Name_Sets.Set
   is
      Result : Name_Sets.Set;
      Entries : Syntax.Name_Vectors.Vector;
      procedure Load (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Entries := Analysis.Documented_Executables (Text);
      end Load;
   begin
      Support.Inspect_File (Repository, Documentation_Path, Load'Access);
      for Item of Entries loop
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Item);
         begin
            if Result.Contains (Name) then
               Fail
                 (Documentation_Path &
                  " contains duplicate tool executable: " & Name);
            end if;
            Result.Insert (Name);
         end;
      end loop;
      return Result;
   end Read_Documented_Executables;

   procedure Require_Exact_Inventory
     (Expected : Name_Sets.Set;
      Documented : Name_Sets.Set;
      Documentation_Path : String) is
   begin
      for Name of Expected loop
         if not Documented.Contains (Name) then
            Fail
              (Documentation_Path & " does not document tool executable: " &
               Name);
         end if;
      end loop;
      for Name of Documented loop
         if not Expected.Contains (Name) then
            Fail
              (Documentation_Path & " documents stale tool executable: " &
               Name);
         end if;
      end loop;
   end Require_Exact_Inventory;

   procedure Require_Main_Inventories
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Source_Caches.Cache;
      Configuration : Inventory.Plan;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Documentation_Path : constant String :=
        Inventory.Documentation_Path_Of (Configuration);
      Expected : Name_Sets.Set;
      Documented : constant Name_Sets.Set :=
        Read_Documented_Executables
          (Repository, Documentation_Path, Budget);
      procedure Validate_Project
        (Project_Path : String; Source_Directory : String) is
         Description : constant Inventory.Project_Inventory :=
           (Ada.Strings.Unbounded.To_Unbounded_String (Project_Path),
            Ada.Strings.Unbounded.To_Unbounded_String (Source_Directory));
         Project : Analyzed_Project :=
           Load_Project (Repository, Description, Budget);
      begin
         Scan_Project_Sources
           (Repository, Cached_Sources, Project, Budget);
         Validate_Project_Sources (Project);
         Include_Executables (Project, Expected);
      end Validate_Project;
   begin
      Inventory.Visit_Projects (Configuration, Validate_Project'Access);
      Require_Exact_Inventory (Expected, Documented, Documentation_Path);
   end Require_Main_Inventories;
end Giflib_Tooling.Repository_Project_Validation;
