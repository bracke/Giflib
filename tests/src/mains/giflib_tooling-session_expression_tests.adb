with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Expression_Resolution;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Session_Expression_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Expressions renames
     Giflib_Tooling.Session_Expression_Resolution;
   package State renames Giflib_Tooling.Session_State;
   package Bindings renames Giflib_Tooling.Session_State.Bindings;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Run is
      Profile : Semantics.Callable_Profile;
   begin
      declare
         Call_State : State.State;
         Tokens : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex ("copy (");
         Resolved : State.Relation;
         Call_Budget : Budgets.Budget;
      begin
         Bindings.Bind_Callable
           (Call_State, To_Unbounded_String ("copy"),
            Semantics.No_Session_Depth, "decoder_array", "",
            Profile, Call_Budget);
         Resolved := Expressions.Resolve
           (Tokens, Tokens.First_Index, Tokens.Last_Index, Call_State,
            Call_Budget);
         Check.Check
           (Length (Resolved.Declared_Type) = 0,
            "unterminated calls cannot participate in overload resolution");
      end;

      declare
         Call_State : State.State;
         Literal_Profile : Semantics.Callable_Profile;
         Tokens : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex ("copy (1)");
         Resolved : State.Relation;
         Call_Budget : Budgets.Budget;
      begin
         Literal_Profile.Minimum_Arguments := 1;
         Literal_Profile.Maximum_Arguments := 1;
         Literal_Profile.Formal_Types.Append
           (To_Unbounded_String ("custom_integer"));
         Bindings.Bind_Callable
           (Call_State, To_Unbounded_String ("copy"),
            Semantics.No_Session_Depth, "decoder_array", "",
            Literal_Profile, Call_Budget);
         Resolved := Expressions.Resolve
           (Tokens, Tokens.First_Index, Tokens.Last_Index, Call_State,
            Call_Budget);
         Check.Check
           (To_String (Resolved.Declared_Type) = "decoder_array",
            "universal numeric literals conservatively match user types");
      end;

      declare
         Empty_State : State.State;
         Tokens : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex ("if ready then copy else");
         Call_Budget : Budgets.Budget;
         Resolved : constant State.Relation := Expressions.Resolve
           (Tokens, Tokens.First_Index, Tokens.Last_Index, Empty_State,
            Call_Budget);
      begin
         Check.Check
           (Length (Resolved.Declared_Type) = 0,
            "conditional expressions require a branch after else");
      end;
   end Run;
end Giflib_Tooling.Session_Expression_Tests;
