with Ada.Strings.Unbounded;

with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Suite_Registration_Testing;

package body Giflib_Tooling.Suite_Registration_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Suites renames Giflib_Tooling.Suite_Registration_Testing;
   use type Suites.Registration_Issue;

   procedure Run is
      Decoy_Overload : constant String :=
        "package body Sample is " &
        "function All_Tests (Flag : Boolean) return Suite_Access is " &
        "begin return Other_Suite; end All_Tests; " &
        "function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin " &
        "Suite.Add_Test (Item); return Suite; end All_Tests; end Sample;";
      Duplicate_Registration : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin " &
        "Suite.Add_Test (Item); Suite.Add_Test (Item); " &
        "return Suite; end All_Tests; end Sample;";
      Nested_Overload : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; " &
        "function All_Tests (Flag : Boolean) return Suite_Access is " &
        "begin return Other_Suite; end All_Tests; begin " &
        "Suite.Add_Test (Item); return Suite; end All_Tests; end Sample;";
      Nested_Block : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin " &
        "Suite.Add_Test (Item); declare Value : Natural; begin Value := 1; " &
        "end; return Suite; end All_Tests; end Sample;";
      Conflicting_Returns : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin " &
        "Suite.Add_Test (Item); if Flag then return Other_Suite; end if; " &
        "return Suite; end All_Tests; end Sample;";
      Dead_Registration : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin if False then " &
        "Suite.Add_Test (Item); end if; return Suite; end All_Tests; end Sample;";
      Conditional_Registration : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; Flag : Boolean := True; " &
        "begin if Flag then Suite.Add_Test (Item); end if; return Suite; " &
        "end All_Tests; end Sample;";
      True_Else_Registration : constant String :=
        "package body Sample is function All_Tests return Suite_Access is " &
        "Suite : Suite_Access; Item : Test_Access := " &
        "new Giflib.Testing.Test_Decoder.Test; begin if True then null; " &
        "else Suite.Add_Test (Item); end if; return Suite; end All_Tests; " &
        "end Sample;";
      Decoy_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Decoy_Overload);
      Duplicate_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Duplicate_Registration);
      Nested_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Nested_Overload);
      Block_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Nested_Block);
      Conflict_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Conflicting_Returns);
      Dead_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Dead_Registration);
      Conditional_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (Conditional_Registration);
      True_Else_Result : constant Suites.Registration_Inventory :=
        Suites.Registrations (True_Else_Registration);
   begin
      Check.Check
        (Name_Collections.Contains
           (Decoy_Result.Units, "giflib.testing.test_decoder"),
         "suite registration selects the parameterless top-level All_Tests body");
      Check.Check
        (Length (Duplicate_Result.Duplicate) > 0,
         "suite registration reports duplicate Add_Test calls");
      Check.Check
        (Name_Collections.Contains
           (Nested_Result.Units, "giflib.testing.test_decoder"),
         "nested same-name overloads cannot truncate suite registration");
      Check.Check
        (Name_Collections.Contains
           (Block_Result.Units, "giflib.testing.test_decoder"),
         "nested blocks preserve the All_Tests executable-body boundary");
      Check.Check
        (Conflict_Result.Issue = Suites.Suite_Return_Ambiguous,
         "every All_Tests return path must select the same suite");
      Check.Check
        (Dead_Result.Units.Is_Empty,
         "dead Add_Test calls are not registrations");
      Check.Check
        (Conditional_Result.Units.Is_Empty,
         "conditional Add_Test calls are not registrations");
      Check.Check
        (True_Else_Result.Units.Is_Empty,
         "unreachable else-branch Add_Test calls are not registrations");
   end Run;
end Giflib_Tooling.Suite_Registration_Tests;
