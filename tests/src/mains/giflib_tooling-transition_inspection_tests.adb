with Ada.Strings.Unbounded;

with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Transition_Inspection;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Transitions;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Work_Budgets.Testing;

package body Giflib_Tooling.Transition_Inspection_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Source renames Giflib_Tooling.Source_Model;
   package Inspection renames Giflib_Tooling.Transition_Inspection;
   package Policies renames Giflib_Tooling.Transition_Policy;
   package Transitions renames Giflib_Tooling.Transitions;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Budget_Testing renames Giflib_Tooling.Work_Budgets.Testing;

   procedure Run is
      Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Sessions : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Local_Calls : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      procedure Expect (Text : String; Message : String) is
      begin
         Check.Check
           (Transitions.Violation (Source.Lex (Text), Fields, Sessions),
            Message);
      end Expect;
   begin
      Fields.Append (To_Unbounded_String ("current_state"));
      Fields.Append (To_Unbounded_String ("warnings"));
      Sessions.Append (To_Unbounded_String ("object"));
      Sessions.Append (To_Unbounded_String ("session"));
      Sessions.Append (To_Unbounded_String ("pointer"));
      Local_Calls.Append (To_Unbounded_String ("complete"));
      Expect ("Object.Current_State := Ready", "direct state assignment");
      Expect ("Sneak (Object.Current_State)", "unknown protected-field helper");
      Expect ("Sneak. (Object)", "unrecognized call syntax fails closed");
      Expect
        ("Sneak ((Object.Current_State))", "grouped protected-field helper");
      Expect
        ("Session.Current_State := Ready", "differently named session assignment");
      Expect
        ("Resource_Management.Release_And_Mutate (Object)",
         "approved-call prefix collision");
      Check.Check
        (not Transitions.Violation
           (Source.Lex ("Lifecycle_Sequence.Release_And_Cancel (Object)"), Fields,
            Sessions, "giflib-decoding.adb"),
         "exact approved call");
      Expect ("Alias : Decoder renames Object", "whole-session alias");
      Expect
        ("Pointer := Object'Unrestricted_Access", "whole-session access alias");
      Expect ("Location := Object'Address", "whole-session address alias");
      Expect
        ("Pointer := Object.Current_State'Unchecked_Access",
         "protected-field access alias");
      Expect
        ("Pointer := Object.Warnings (1)'Unrestricted_Access",
         "indexed protected-field access alias");
      Expect
        ("Pointer := (Object.Current_State)'Unrestricted_Access",
         "grouped protected-field access alias");
      Expect
        ("Pointer.all.Current_State := Initialized",
         "explicit session dereference assignment");
      Expect
        ("Sneak (Pointer.all)", "explicit whole-session dereference call");
      Expect
        ("Sneak (Pointer.all.all)",
         "multi-level whole-session dereference call");
      Check.Check
        (Transitions.Violation
           (Source.Lex ("Complete (Object)"), Fields, Sessions,
            "unreviewed.adb"),
         "undeclared local call");
      Check.Check
        (not Inspection.Violation
           (Source.Lex ("Complete (Object)"), Fields, Sessions,
            Policies.Load, "unreviewed.adb", Local_Calls),
         "parsed local declaration approval");
      Check.Check
        (not Transitions.Violation
           (Source.Lex ("X := ';'; -- Object.Current_State := Failed"), Fields,
            Sessions),
         "literal and comment isolation");
      declare
         Budget : Budgets.Budget;
         Seen : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
         Found : constant Boolean := Inspection.Analyze
           (Source.Lex ("Object.Current_State := Ready"), Fields, Sessions,
            Policies.Load, "",
            Giflib_Tooling.Name_Collections.Name_Vectors.Empty_Vector,
            Seen, Budget);
      begin
         Check.Check
           (Found
            and then not Budget_Testing.Can_Charge
              (Budget, Budgets.Maximum_Work - 10),
            "transition inspection charges its shared work budget");
      end;
   end Run;
end Giflib_Tooling.Transition_Inspection_Tests;
