with Giflib_Tooling.Source_Units;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Analysis_Contexts;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Transition_Sources;
with Giflib_Tooling.Transition_Storage;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Storage_Budgets;

package body Giflib_Tooling.Transition_Source_Cache_Tests is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Units.Separate_Clause_Kind;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Sources renames Giflib_Tooling.Transition_Sources;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Run is
      procedure Check_Source_Snapshot is
         Root : constant String :=
           Fixtures.Fresh_Temp_Dir ("giflib-source-snapshot");
         Path : constant String :=
           Files.Join (Root, "src/giflib-decoding-child.adb");
         First_Parent : Unbounded_String;
         Second_Parent : Unbounded_String;
         Pass : Natural := 0;
         Storage_Rejected : Boolean := False;
         Storage_Used : Natural := 0;
         Expected_Storage : Natural := 0;
         procedure Capture
           (Name : String;
            Parsed : Sources.Source.Parsed_Source;
            Clause : Giflib_Tooling.Source_Units.Separate_Clause) is
            pragma Unreferenced (Name, Parsed);
         begin
            Pass := Pass + 1;
            if Clause.Kind = Giflib_Tooling.Source_Units.Valid_Separate_Clause then
               if Pass = 1 then
                  First_Parent := Clause.Parent;
               else
                  Second_Parent := Clause.Parent;
               end if;
            end if;
         end Capture;
         procedure Inspect_Analysis
           (Snapshot : aliased in
              Giflib_Tooling.Repository_Snapshots.Snapshot;
            Cached_Sources : aliased in
              Giflib_Tooling.Repository_Source_Cache.Cache;
            Work : aliased in out Giflib_Tooling.Work_Budgets.Budget;
            Storage : aliased in out
              Giflib_Tooling.Validation_Storage_Budgets.Budget)
         is
            Repository : Sources.Repository;
            Clause : constant Giflib_Tooling.Source_Units.Separate_Clause :=
              (Kind => Giflib_Tooling.Source_Units.Valid_Separate_Clause,
               Parent => To_Unbounded_String ("giflib.decoding.first"));
            procedure Measure_Names
              (Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
               Callable_Names :
                 Giflib_Tooling.Name_Collections.Name_Vectors.Vector) is
            begin
               for Name of Type_Names loop
                  Expected_Storage := Expected_Storage +
                    Giflib_Tooling.Transition_Storage.Name_Units
                      (To_String (Name));
               end loop;
               for Name of Callable_Names loop
                  Expected_Storage := Expected_Storage +
                    Giflib_Tooling.Transition_Storage.Name_Units
                      (To_String (Name));
               end loop;
            end Measure_Names;
         begin
            Sources.Build
              (Repository, Snapshot, Cached_Sources, Work, Storage);
            Expected_Storage :=
              Giflib_Tooling.Transition_Storage.Indexed_Unit_Units
                ("giflib-decoding-child.adb", Path, Clause);
            Sources.Visit_Declarations
              (Repository, "giflib-decoding-child.adb",
               Measure_Names'Access);
            Storage_Used :=
              Giflib_Tooling.Validation_Storage_Budgets.Used (Storage);
            declare
               Rebuild_Rejected : Boolean := False;
            begin
               begin
                  Sources.Build
                    (Repository, Snapshot, Cached_Sources, Work, Storage);
               exception
                  when Program_Error =>
                     Rebuild_Rejected := True;
               end;
               Check.Check
                 (Rebuild_Rejected
                  and then Sources.Count (Repository) = 1
                  and then
                    Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) =
                      Storage_Used,
                  "source repository rejects rebuild without changing state");
            end;
            Sources.Inspect
              (Repository, Cached_Sources, "giflib-decoding-child.adb", Work,
               Capture'Access);
            Fixtures.Write_Text_File
              (Path,
               "separate (Giflib.Decoding.Second) procedure Child is " &
               "begin null; end Child;");
            Sources.Inspect
              (Repository, Cached_Sources, "giflib-decoding-child.adb", Work,
               Capture'Access);
            declare
               Tiny_Storage : aliased
                 Giflib_Tooling.Validation_Storage_Budgets.Budget
                 (0);
               Rejected_Repository : Sources.Repository;
            begin
               begin
                  Sources.Build
                    (Rejected_Repository, Snapshot, Cached_Sources, Work,
                     Tiny_Storage);
               exception
                  when Input_Error =>
                     Storage_Rejected := True;
               end;
            end;
         end Inspect_Analysis;
      begin
         Fixtures.Make_Directory (Files.Join (Root, "src"));
         Fixtures.Write_Text_File
           (Path,
            "separate (Giflib.Decoding.First) procedure Child is " &
            "begin null; end Child;");
         declare
            Analysis : Giflib_Tooling.Analysis_Contexts.Context :=
              Giflib_Tooling.Analysis_Contexts.Build
                (Root, Giflib_Tooling.Repository_Snapshots.Source_Only);
         begin
            Giflib_Tooling.Analysis_Contexts.Inspect
              (Analysis, Inspect_Analysis'Access);
         end;
         Check.Check
           (To_String (First_Parent) = "giflib.decoding.first"
            and then Second_Parent = First_Parent,
            "source cache preserves one immutable inspection snapshot");
         Check.Check
           (Storage_Rejected,
            "transition indexing enforces retained storage limits");
         Check.Check
           (Storage_Used = Expected_Storage,
            "transition storage charges the shared measured schema exactly");
         Fixtures.Cleanup (Root);
      exception
         when others =>
            Fixtures.Cleanup (Root);
            raise;
      end Check_Source_Snapshot;

      procedure Check_Source_Model_Budget is
         Root : constant String :=
           Fixtures.Fresh_Temp_Dir ("giflib-source-model-budget");
         Rejected : Boolean := False;
         Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
           Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
         Budget : Budgets.Budget;
      begin
         Fixtures.Make_Directory (Files.Join (Root, "src"));
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/probe.ads"),
            "package Probe is end Probe;");
         Limits.Cache.Maximum_Cached_Model_Units := 1;
         declare
            Snapshot : constant Giflib_Tooling.Repository_Snapshots.Snapshot :=
              Giflib_Tooling.Repository_Snapshots.Build
                (Root, Giflib_Tooling.Repository_Snapshots.Source_Only,
                 Limits);
         begin
            declare
               Ignored : constant
                 Giflib_Tooling.Repository_Source_Cache.Cache :=
                   Giflib_Tooling.Repository_Source_Cache.Build
                     (Snapshot, Budget);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Input_Error =>
               Rejected := True;
         end;
         Check.Check
           (Rejected, "parsed source cache enforces its storage-unit budget");
         Fixtures.Cleanup (Root);
      exception
         when others =>
            Fixtures.Cleanup (Root);
            raise;
      end Check_Source_Model_Budget;

      procedure Check_Source_Work_Budget is
         Root : constant String :=
           Fixtures.Fresh_Temp_Dir ("giflib-source-work-budget");
         Rejected : Boolean := False;
         Budget : Budgets.Budget (0);
      begin
         Fixtures.Make_Directory (Files.Join (Root, "src"));
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/probe.ads"),
            "package Probe is end Probe;");
         declare
            Snapshot : constant Giflib_Tooling.Repository_Snapshots.Snapshot :=
              Giflib_Tooling.Repository_Snapshots.Build
                (Root, Giflib_Tooling.Repository_Snapshots.Source_Only);
         begin
            declare
               Ignored : constant
                 Giflib_Tooling.Repository_Source_Cache.Cache :=
                   Giflib_Tooling.Repository_Source_Cache.Build
                     (Snapshot, Budget);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Budgets.Work_Limit_Exceeded =>
               Rejected := True;
         end;
         Check.Check
           (Rejected, "parsed source cache charges work before source copies");
         Fixtures.Cleanup (Root);
      exception
         when others =>
            Fixtures.Cleanup (Root);
            raise;
      end Check_Source_Work_Budget;
   begin
      Check_Source_Snapshot;
      Check_Source_Model_Budget;
      Check_Source_Work_Budget;
   end Run;
end Giflib_Tooling.Transition_Source_Cache_Tests;
