with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Suite_Routine_Testing;

package body Giflib_Tooling.Suite_Routine_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Routines renames Giflib_Tooling.Suite_Routine_Testing;

   procedure Run is
      Decoy_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Register_Routine : Natural; begin null; " &
        "end Register_Tests; end Sample;";
      Active_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin Register_Routine (T, Probe'Access, " &
        """probe""); end Register_Tests; end Sample;";
      Routine_With_Block : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin Register_Routine (T, Probe'Access, " &
        """probe""); declare Value : Natural; begin Value := 1; end; " &
        "end Register_Tests; end Sample;";
      Wrong_Target_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Other : Test; begin " &
        "Register_Routine (Other, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Dead_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin if False then " &
        "Register_Routine (T, Probe'Access, ""probe""); end if; " &
        "end Register_Tests; end Sample;";
      Conditional_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean := True; begin if Flag then " &
        "Register_Routine (T, Probe'Access, ""probe""); end if; " &
        "end Register_Tests; end Sample;";
      Labeled_Conditional_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean := True; begin " &
        "<<Guard>> if Flag then Register_Routine " &
        "(T, Probe'Access, ""probe""); end if; " &
        "end Register_Tests; end Sample;";
      Terminated_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin return; " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Expression_Before_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean := True; Value : Natural; " &
        "begin Value := (if Flag then 1 else 2); " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Named_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin Register_Routine " &
        "(Routine => Probe'Access, Test => T, Name => ""probe""); " &
        "end Register_Tests; end Sample;";
      Grouped_Profile_Routine : constant String :=
        "package body Sample is procedure Register_Tests " &
        "(First, T : in out Test) is begin Register_Routine " &
        "(First, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Handler_Only_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin Probe; exception when others => " &
        "declare type Item is record Value : Natural; end record; " &
        "begin null; end; " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Named_Block_Handler_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin Probe; exception when others => " &
        "Inner : begin null; end Inner; " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Package_In_Block_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin declare package Local is end; " &
        "begin null; exception when others => null; end; " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Handled_Raise_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin declare begin raise Constraint_Error; " &
        "exception when others => null; end; Register_Routine " &
        "(T, Probe'Access, ""probe""); end Register_Tests; end Sample;";
      Handled_Raise_With_Dead_Terminators : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin declare begin raise Constraint_Error; " &
        "return; goto Skip; exception when others => null; end; " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "<<Skip>> null; end Register_Tests; end Sample;";
      Nested_Handled_Raise_In_Handler : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin declare begin raise Constraint_Error; " &
        "exception when others => declare begin raise Program_Error; " &
        "exception when others => null; end; end; Register_Routine " &
        "(T, Probe'Access, ""probe""); end Register_Tests; end Sample;";
      Forward_Goto_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin goto Join; null; <<Join>> " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Forward_Goto_Terminator_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is begin goto Join; return; <<Join>> " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Composed_Goto_Terminator_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean; begin if Flag then " &
        "goto Alternate; end if; goto Join; return; <<Alternate>> null; " &
        "<<Join>> Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Repeated_Target_Goto_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean; begin if Flag then " &
        "goto Join; end if; goto Join; return; <<Join>> " &
        "Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Composed_Goto_Reachable_Return_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean; begin if Flag then " &
        "goto Alternate; end if; goto Join; <<Alternate>> return; " &
        "<<Join>> Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";
      Skipping_Goto_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean; begin if Flag then " &
        "goto Done; end if; Register_Routine " &
        "(T, Probe'Access, ""probe""); <<Done>> null; " &
        "end Register_Tests; end Sample;";
      Conditional_Return_Routine : constant String :=
        "package body Sample is overriding procedure Register_Tests " &
        "(T : in out Test) is Flag : Boolean; begin if Flag then return; " &
        "end if; Register_Routine (T, Probe'Access, ""probe""); " &
        "end Register_Tests; end Sample;";

   begin
      Check.Check
        (not Routines.Registers_Test_Routine (Decoy_Routine),
         "a declaration named Register_Routine is not a registration call");
      Check.Check
        (Routines.Registers_Test_Routine (Active_Routine),
         "Register_Tests recognizes a direct registration call");
      Check.Check
        (Routines.Registers_Test_Routine (Routine_With_Block),
         "nested blocks preserve the Register_Tests executable-body boundary");
      Check.Check
        (not Routines.Registers_Test_Routine (Wrong_Target_Routine),
         "registration calls must target the test parameter");
      Check.Check
        (not Routines.Registers_Test_Routine (Dead_Routine),
         "dead registration calls are rejected");
      Check.Check
        (not Routines.Registers_Test_Routine (Conditional_Routine),
         "conditional registration calls are rejected");
      Check.Check
        (not Routines.Registers_Test_Routine (Labeled_Conditional_Routine),
         "labels do not make conditional registrations unconditional");
      Check.Check
        (not Routines.Registers_Test_Routine (Terminated_Routine),
         "registration calls after returns are rejected");
      Check.Check
        (not Routines.Registers_Test_Routine (Grouped_Profile_Routine),
         "grouped profiles preserve the actual test parameter");
      Check.Check
        (not Routines.Registers_Test_Routine (Handler_Only_Routine),
         "handler-only registration calls are rejected");
      Check.Check
        (not Routines.Registers_Test_Routine (Named_Block_Handler_Routine),
         "named handler blocks remain conditionally reachable");
      Check.Check
        (Routines.Registers_Test_Routine (Expression_Before_Routine),
         "conditional expressions do not make later calls conditional");
      Check.Check
        (Routines.Registers_Test_Routine (Named_Routine),
         "named registration arguments are recognized");
      Check.Check
        (Routines.Registers_Test_Routine (Package_In_Block_Routine),
         "local packages do not hide later registration calls");
      Check.Check
        (Routines.Registers_Test_Routine (Handled_Raise_Routine),
         "handled raises preserve later registration reachability");
      Check.Check
        (Routines.Registers_Test_Routine
           (Handled_Raise_With_Dead_Terminators),
         "dead terminators after raises do not poison handled flow");
      Check.Check
        (Routines.Registers_Test_Routine (Nested_Handled_Raise_In_Handler),
         "nested handled raises remain independent from outer handlers");
      Check.Check
        (Routines.Registers_Test_Routine (Forward_Goto_Routine),
         "forward goto joins restore registration reachability");
      Check.Check
        (Routines.Registers_Test_Routine (Forward_Goto_Terminator_Routine),
         "unreachable terminators do not poison forward goto joins");
      Check.Check
        (Routines.Registers_Test_Routine (Composed_Goto_Terminator_Routine),
         "composed goto paths ignore globally unreachable terminators");
      Check.Check
        (Routines.Registers_Test_Routine (Repeated_Target_Goto_Routine),
         "repeated goto targets still suppress unreachable terminators");
      Check.Check
        (not Routines.Registers_Test_Routine
           (Composed_Goto_Reachable_Return_Routine),
         "goto labels reactivate terminators on reachable alternate paths");
      Check.Check
        (not Routines.Registers_Test_Routine (Skipping_Goto_Routine),
         "gotos that skip registration calls are rejected");
      Check.Check
        (not Routines.Registers_Test_Routine (Conditional_Return_Routine),
         "conditional returns prevent unconditional registration");
   end Run;
end Giflib_Tooling.Suite_Routine_Tests;
