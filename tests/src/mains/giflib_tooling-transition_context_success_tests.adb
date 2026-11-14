with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Analysis_Contexts;
with Giflib_Tooling.Transition_Index;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Name_Collections;

package body Giflib_Tooling.Transition_Context_Success_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Index renames Giflib_Tooling.Transition_Index;

   procedure Run is
      Root : constant String :=
        Fixtures.Fresh_Temp_Dir ("giflib-nested-context");
      Found : Boolean := False;
      Saw_Root : Boolean := False;
      Saw_Family : Boolean := False;
      Saw_Target : Boolean := False;
      Saw_Unrelated : Boolean := False;
      Saw_Nested_Decoy : Boolean := False;
      procedure Inspect
        (Name : String;
         Parsed : Index.Source.Parsed_Source;
         Context : Index.Semantics.Type_Classification_Vectors.Vector)
      is
         pragma Unreferenced (Parsed);
      begin
         for Item of Context loop
            if To_String (Item.Name) = "nested_alias"
              and then Index.Semantics.Relation_Of (Item).Depth.Present
              and then Name = "giflib-decoding-parent-child.adb"
            then
               Found := True;
            end if;
         end loop;
      end Inspect;
   begin
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/giflib.ads"),
         "package Giflib is type Root_Type is range 0 .. 1; end Giflib;");
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/giflib-decoding.ads"),
         "package Giflib.Decoding is type Decoder is tagged null record; " &
         "end Giflib.Decoding;");
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/giflib-decoding.adb"),
         "package body Giflib.Decoding is begin null; end Giflib.Decoding;");
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/giflib-decoding-parent.adb"),
         "separate (Giflib.Decoding) procedure Parent is " &
         "subtype Nested_Alias is Decoder; procedure Child is separate; " &
         "begin null; end Parent;");
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/giflib-decoding-parent-child.adb"),
         "separate (Giflib.Decoding.Parent) procedure Child is " &
         "package Hidden is type Nested_Decoy is tagged null record; " &
         "end Hidden; begin null; end Child;");
      Fixtures.Write_Text_File
        (Files.Join (Root, "src/unrelated.ads"),
         "package Unrelated is type Decoder is tagged null record; " &
         "procedure Child; end Unrelated;");
      declare
         Analysis : Giflib_Tooling.Analysis_Contexts.Context :=
           Giflib_Tooling.Analysis_Contexts.Build
             (Root, Giflib_Tooling.Repository_Snapshots.Source_Only);
         procedure Note_Visible
           (Name : String;
            Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
            Callable_Names :
              Giflib_Tooling.Name_Collections.Name_Vectors.Vector) is
            pragma Unreferenced (Callable_Names);
         begin
            Saw_Root := Saw_Root or else Name = "giflib.ads";
            Saw_Family := Saw_Family or else Name = "giflib-decoding.ads";
            Saw_Target :=
              Saw_Target or else
              Name = "giflib-decoding-parent-child.adb";
            Saw_Unrelated := Saw_Unrelated or else Name = "unrelated.ads";
            Saw_Nested_Decoy :=
              Saw_Nested_Decoy
              or else
                (Name = "giflib-decoding-parent-child.adb"
                 and then Giflib_Tooling.Name_Collections.Contains
                   (Type_Names, "nested_decoy"));
         end Note_Visible;
         procedure Inspect_Analysis
           (Snapshot : aliased in
              Giflib_Tooling.Repository_Snapshots.Snapshot;
            Cached_Sources : aliased in
              Giflib_Tooling.Repository_Source_Cache.Cache;
            Budget : aliased in out Giflib_Tooling.Work_Budgets.Budget;
            Storage : aliased in out
              Giflib_Tooling.Validation_Storage_Budgets.Budget)
         is
            Bound : aliased Index.Resources
              (Snapshot'Access, Cached_Sources'Access, Budget'Access,
               Storage'Access);
            Repository : Index.Source_Index (Bound'Access);
            procedure Inspect_Text (Text : String) is
               Parsed : constant Index.Source.Parsed_Source :=
                 Index.Source.Parse (Text);
            begin
               Index.Inspect_Visible_Sources
                 (Repository, "giflib-decoding",
                  "giflib-decoding-parent-child.adb",
                  Index.Source.Separate_Clause_Of (Parsed),
                  Note_Visible'Access);
            end Inspect_Text;
         begin
            Index.Build (Repository);
            Index.Scan_Family
              (Repository, "giflib-decoding", "giflib-decoding.adb",
               Index.Identity.Create_Known
                 ("decoder", "giflib.decoding.decoder"),
               Inspect'Access);
            Giflib_Tooling.Repository_Snapshots.Inspect_Text
              (Snapshot, "src/giflib-decoding-parent-child.adb",
               Inspect_Text'Access);
         end Inspect_Analysis;
      begin
         Giflib_Tooling.Analysis_Contexts.Inspect
           (Analysis, Inspect_Analysis'Access);
      end;
      Fixtures.Cleanup (Root);
      Check.Check (Found, "nested subunits inherit parent-body context");
      Check.Check
        (Saw_Root and then Saw_Family and then Saw_Target,
         "transition trust includes only the target's visible ancestry");
      Check.Check
        (not Saw_Unrelated,
         "transition trust excludes unrelated source declarations");
      Check.Check
        (not Saw_Nested_Decoy,
         "transition trust excludes nested local type declarations");
   exception
      when others =>
         Fixtures.Cleanup (Root);
         raise;
   end Run;
end Giflib_Tooling.Transition_Context_Success_Tests;
