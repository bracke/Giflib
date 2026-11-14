with Ada.Exceptions;

with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Analysis_Contexts;
with Giflib_Tooling.Transition_Index;
with Giflib_Tooling.Repository_Snapshots;
with Giflib_Tooling.Repository_Source_Cache;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Storage_Budgets;

package body Giflib_Tooling.Transition_Context_Failure_Tests is
   use type Ada.Exceptions.Exception_Id;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Index renames Giflib_Tooling.Transition_Index;

   procedure Run is
      procedure Write_Base (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding.ads"),
            "package Giflib.Decoding is " &
            "type Decoder is tagged null record; end Giflib.Decoding;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding.adb"),
            "package body Giflib.Decoding is begin null; " &
            "end Giflib.Decoding;");
      end Write_Base;

      procedure Ignore
        (Name : String;
         Parsed : Index.Source.Parsed_Source;
         Context : Index.Semantics.Type_Classification_Vectors.Vector)
      is
         pragma Unreferenced (Name, Parsed, Context);
      begin
         null;
      end Ignore;

      procedure Scan
        (Root : String;
         Maximum_Context_Depth : Positive := Budgets.Maximum_Depth)
      is
         Analysis : Giflib_Tooling.Analysis_Contexts.Context :=
           Giflib_Tooling.Analysis_Contexts.Build
             (Root, Giflib_Tooling.Repository_Snapshots.Source_Only);
         procedure Inspect_Analysis
           (Snapshot : aliased in
              Giflib_Tooling.Repository_Snapshots.Snapshot;
            Cached_Sources : aliased in
              Giflib_Tooling.Repository_Source_Cache.Cache;
            Budget : aliased in out Budgets.Budget;
            Storage : aliased in out
              Giflib_Tooling.Validation_Storage_Budgets.Budget)
         is
            Bound : aliased Index.Resources
              (Snapshot'Access, Cached_Sources'Access, Budget'Access,
               Storage'Access);
            Repository : Index.Source_Index (Bound'Access);
         begin
            Index.Build
              (Repository, Maximum_Context_Depth);
            Index.Scan_Family
              (Repository, "giflib-decoding", "giflib-decoding.adb",
               Index.Identity.Create_Known
                 ("decoder", "giflib.decoding.decoder"),
               Ignore'Access);
         end Inspect_Analysis;
      begin
         Giflib_Tooling.Analysis_Contexts.Inspect
           (Analysis, Inspect_Analysis'Access);
      end Scan;

      procedure Expect_Failure
        (Fixture_Name : String;
         Configure : not null access procedure (Root : String);
         Expected_Id : Ada.Exceptions.Exception_Id;
         Expected_Message : String;
         Check_Message : String;
         Maximum_Context_Depth : Positive := Budgets.Maximum_Depth)
      is
         Root : constant String := Fixtures.Fresh_Temp_Dir (Fixture_Name);
         Matched : Boolean := False;
      begin
         Write_Base (Root);
         Configure (Root);
         begin
            Scan (Root, Maximum_Context_Depth);
         exception
            when E : others =>
               if Ada.Exceptions.Exception_Identity (E) /= Expected_Id then
                  raise;
               end if;
               Matched :=
                 Ada.Exceptions.Exception_Message (E) = Expected_Message;
         end;
         Check.Check (Matched, Check_Message);
         Fixtures.Cleanup (Root);
      exception
         when others =>
            Fixtures.Cleanup (Root);
            raise;
      end Expect_Failure;

      procedure Configure_Malformed (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-broken.adb"),
            "separate (Giflib.Decoding) null;");
      end Configure_Malformed;

      procedure Configure_Cycle (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a.adb"),
            "separate (Giflib.Decoding.B) procedure A is begin null; end A;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-b.adb"),
            "separate (Giflib.Decoding.A) procedure B is begin null; end B;");
      end Configure_Cycle;

      procedure Configure_Depth (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a.adb"),
            "separate (Giflib.Decoding) procedure A is begin null; end A;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a-b.adb"),
            "separate (Giflib.Decoding.A) procedure B is begin null; end B;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a-b-c.adb"),
            "separate (Giflib.Decoding.A.B) procedure C is begin null; end C;");
      end Configure_Depth;

      procedure Configure_Missing (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-child.adb"),
            "separate (Giflib.Decoding.Missing) procedure Child is " &
            "begin null; end Child;");
      end Configure_Missing;

      procedure Configure_Specification_Depth (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a.ads"),
            "package Giflib.Decoding.A is end Giflib.Decoding.A;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a-b.ads"),
            "package Giflib.Decoding.A.B is end Giflib.Decoding.A.B;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-a-b-helper.adb"),
            "procedure Helper is begin null; end Helper;");
      end Configure_Specification_Depth;

      procedure Configure_Cross_Family (Root : String) is
      begin
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/other-parent.adb"),
            "package body Other.Parent is end Other.Parent;");
         Fixtures.Write_Text_File
           (Files.Join (Root, "src/giflib-decoding-child.adb"),
            "separate (Other.Parent) procedure Child is " &
            "begin null; end Child;");
      end Configure_Cross_Family;
   begin
      Expect_Failure
        ("giflib-malformed-separate", Configure_Malformed'Access,
         Input_Error'Identity,
         "malformed separate-subunit declaration: giflib-decoding-broken.adb",
         "malformed separate clauses have a specific rejection");
      Expect_Failure
        ("giflib-context-cycle", Configure_Cycle'Access,
         Input_Error'Identity, "cyclic separate-subunit context inheritance",
         "cyclic separate-subunit parents are rejected", 2);
      Expect_Failure
        ("giflib-context-depth", Configure_Depth'Access,
         Budgets.Work_Limit_Exceeded'Identity,
         "context ancestry depth budget exhausted",
         "separate-subunit inheritance enforces its depth limit", 2);
      Expect_Failure
        ("giflib-context-missing", Configure_Missing'Access,
         Input_Error'Identity, "missing separate-subunit parent body",
         "missing separate-subunit parents are rejected");
      Expect_Failure
        ("giflib-specification-context-depth",
         Configure_Specification_Depth'Access,
         Budgets.Work_Limit_Exceeded'Identity,
         "context ancestry depth budget exhausted",
         "specification inheritance enforces the shared depth limit", 2);
      Expect_Failure
        ("giflib-cross-family-context", Configure_Cross_Family'Access,
         Input_Error'Identity,
         "separate-subunit parent is outside transition family: " &
         "other-parent.adb",
         "separate parents cannot cross transition families");
   end Run;
end Giflib_Tooling.Transition_Context_Failure_Tests;
