with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Source_Tokens;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Structural_Scopes;

package body Giflib_Tooling.Source_Structure_Tests is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Events.Structural_Event_Kind;
   use type Giflib_Tooling.Source_Units.Separate_Clause_Kind;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Source renames Giflib_Tooling.Source_Model;
   package Names renames Giflib_Tooling.Source_Names;
   package Scopes renames Giflib_Tooling.Structural_Scopes;

   procedure Run is
      Package_Spec_Has_Scope : Boolean := False;
      Package_Spec_Is_Body : Boolean := True;
      Expression_Function_Is_Body : Boolean := False;
      Expression_Function_Has_Bounds : Boolean := False;
      Aggregate_Function_Is_Non_Scoping : Boolean := False;
      Null_Procedure_Is_Non_Scoping : Boolean := False;
      Boxed_Formal_Is_Non_Scoping : Boolean := False;

      procedure Inspect_Structure
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector)
      is
         pragma Unreferenced (Tokens);
      begin
         for Event of Events loop
            if Event.Kind = Giflib_Tooling.Source_Events.Package_Start then
               Package_Spec_Has_Scope := Event.Package_Introduces_Scope;
               Package_Spec_Is_Body := Event.Package_Is_Body;
            elsif Event.Kind = Giflib_Tooling.Source_Events.Subprogram_Start then
               if To_String (Event.Subprogram_Name) = "aggregate_value" then
                  Aggregate_Function_Is_Non_Scoping :=
                    Event.Header.Is_Body
                      and then not Event.Header.Introduces_Scope;
               else
                  Expression_Function_Is_Body := Event.Header.Is_Body;
                  Expression_Function_Has_Bounds :=
                    Event.Header.Return_Marker.Present
                      and then Event.Header.Declaration_Last.Present
                      and then Event.Header.Return_Marker.Value >
                        Event.Token_Index
                      and then Event.Header.Declaration_Last.Value >
                        Event.Header.Return_Marker.Value;
               end if;
            end if;
         end loop;
      end Inspect_Structure;

      procedure Inspect_Non_Scoping
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector)
      is
         pragma Unreferenced (Tokens);
      begin
         for Event of Events loop
            if Event.Kind = Giflib_Tooling.Source_Events.Subprogram_Start then
               if To_String (Event.Subprogram_Name) = "no_op" then
                  Null_Procedure_Is_Non_Scoping :=
                    not Event.Header.Is_Body
                      and then not Event.Header.Introduces_Scope;
               elsif To_String (Event.Subprogram_Name) = "formal" then
                  Boxed_Formal_Is_Non_Scoping :=
                    not Event.Header.Is_Body
                      and then not Event.Header.Introduces_Scope;
               end if;
            end if;
         end loop;
      end Inspect_Non_Scoping;
   begin
      Check.Check
        (Source.Has_Nested_Program_Unit
           ("procedure Outer is procedure Inner is begin Sink (""end""); " &
            "end Inner; begin null; end Outer;"),
         "string literal keywords do not alter structural events");
      Source.Inspect_Syntax
        (Source.Parse
           ("package Sample is Value : Natural; end Sample; " &
            "function Ready return Boolean is (True); " &
            "function Aggregate_Value return Boolean is [True];"),
         Inspect_Structure'Access);
      Check.Check
        (Package_Spec_Has_Scope and then not Package_Spec_Is_Body,
         "package specifications introduce scopes without being bodies");
      Check.Check
        (Expression_Function_Is_Body and then Expression_Function_Has_Bounds,
         "expression functions retain body identity and bounds");
      Check.Check
        (Aggregate_Function_Is_Non_Scoping,
         "aggregate expression functions do not retain phantom scopes");
      Source.Inspect_Syntax
        (Source.Parse
           ("procedure No_Op is null; generic with procedure Formal is <>; " &
            "procedure Generic_Unit;"),
         Inspect_Non_Scoping'Access);
      Check.Check
        (Null_Procedure_Is_Non_Scoping
         and then Boxed_Formal_Is_Non_Scoping,
         "null and boxed formal subprograms do not introduce scopes");
      Check.Check
        (Source.Has_Nested_Program_Unit
           ("procedure Outer is procedure Complete is begin null; " &
            "end Complete; begin null; end Outer;"),
         "nested declaration detection");
      Check.Check
        (not Source.Has_Nested_Program_Unit
           ("procedure First is begin null; end; " &
            "procedure Second is begin null; end;"),
         "unnamed endings close sibling program units");
      Check.Check
        (not Source.Has_Nested_Program_Unit
           ("procedure Outer is type Callback is access procedure " &
            "(Value : Natural); type Protected_Callback is access protected " &
            "procedure (Value : Natural); begin null; end Outer;"),
         "access-to-subprogram types are not program units");
      declare
         Valid : constant Giflib_Tooling.Source_Units.Separate_Clause :=
           Source.Separate_Clause_Of
             (Source.Parse
                ("with Ada.Streams; use Ada; " &
                 "separate (Giflib.Decoding.Extensions) " &
                 "procedure Probe is begin null; end Probe;"));
         Malformed : constant Source.Parsed_Source :=
           Source.Parse
             ("separate (Giflib.Decoding " &
              "procedure Probe is begin null; end Probe;");
      begin
         Check.Check
           (Valid.Kind = Giflib_Tooling.Source_Units.Valid_Separate_Clause
            and then To_String (Valid.Parent) = "giflib.decoding.extensions",
            "separate parent survives leading context clauses");
         Check.Check
           (Source.Separate_Clause_Of (Malformed).Kind =
              Giflib_Tooling.Source_Units.Malformed_Separate_Clause,
            "unterminated separate parents are distinguished from absence");
         Check.Check
           (Source.Separate_Clause_Of
              (Source.Parse ("separate (Giflib.Decoding) null;")).Kind =
              Giflib_Tooling.Source_Units.Malformed_Separate_Clause,
            "separate clauses require a body introducer");
         Check.Check
           (Source.Separate_Clause_Of
              (Source.Parse
                 ("separate Giflib.Decoding procedure Probe is " &
                  "begin null; end Probe;")).Kind =
              Giflib_Tooling.Source_Units.Malformed_Separate_Clause,
            "malformed separate headers cannot become ordinary bodies");
         Check.Check
           (Source.Separate_Clause_Of
              (Source.Parse
                 ("separate (Giflib.Decoding) procedure Probe;")).Kind =
              Giflib_Tooling.Source_Units.Malformed_Separate_Clause,
            "separate clauses require a complete body declaration");
         Check.Check
           (Source.Separate_Clause_Of
              (Source.Parse ("procedure Probe is begin null; end Probe;")).Kind =
              Giflib_Tooling.Source_Units.No_Separate_Clause,
            "ordinary bodies report no separate clause");
         Check.Check
           (Source.Separate_Clause_Of
              (Source.Parse
                 ("procedure Probe is procedure Child is separate; " &
                  "begin null; end Probe;")).Kind =
              Giflib_Tooling.Source_Units.No_Separate_Clause,
            "nested body stubs are not separate-unit headers");
      end;
      Check.Check
        (Names.In_Family ("giflib-decoding-reset.adb", "giflib-decoding")
         and then Names.In_Family ("giflib-decoding.adb", "giflib-decoding")
         and then not Names.In_Family
           ("giflib-decoding_helper.adb", "giflib-decoding"),
         "source families use Ada child-unit boundaries");
      Check.Check
        (Names.Specification_File_Name ("Giflib.Decoding") =
           "giflib-decoding.ads"
         and then Names.Body_File_Name ("Giflib.Decoding") =
           "giflib-decoding.adb"
         and then Names.Unit_Name ("giflib-decoding-reset.adb") =
           "giflib.decoding.reset"
         and then Names.Unit_Name (".adb") = ".adb",
         "source unit and file names use one canonical conversion");
      declare
         Stack : Scopes.Scope_Stack;
         Closed : Scopes.Optional_Scope_Frame;
         Mismatch_Rejected : Boolean := False;
         Unmatched_Rejected : Boolean := False;
         Record_Mismatch_Rejected : Boolean := False;
      begin
         Check.Check
           (not Scopes.Top (Stack).Present,
            "empty structural scope stacks have no top frame");
         Scopes.Push (Stack, Scopes.Block_Scope, Null_Unbounded_String);
         begin
            Scopes.Close
              (Stack, To_Unbounded_String ("wrong_name"), Closed);
         exception
            when Input_Error => Mismatch_Rejected := True;
         end;
         Check.Check
           (Mismatch_Rejected and then Scopes.Top (Stack).Present,
            "named mismatches are rejected without changing the stack");
         Scopes.Close (Stack, Null_Unbounded_String, Closed);
         Check.Check
           (Closed.Present, "anonymous endings close anonymous blocks");
         begin
            Scopes.Close (Stack, Null_Unbounded_String, Closed);
         exception
            when Input_Error => Unmatched_Rejected := True;
         end;
         Scopes.Push (Stack, Scopes.Block_Scope, Null_Unbounded_String);
         begin
            Scopes.Close_Record (Stack, Closed);
         exception
            when Input_Error => Record_Mismatch_Rejected := True;
         end;
         Check.Check
           (Unmatched_Rejected and then Record_Mismatch_Rejected
            and then Scopes.Top (Stack).Present,
            "unmatched anonymous and record endings are rejected");
         Scopes.Close (Stack, Null_Unbounded_String, Closed);
      end;
   end Run;
end Giflib_Tooling.Source_Structure_Tests;
