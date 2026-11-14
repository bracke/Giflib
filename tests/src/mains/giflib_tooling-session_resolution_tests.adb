with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Package_Aliases;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_State.Aliases;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Resolution;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Work_Budgets.Testing;

package body Giflib_Tooling.Session_Resolution_Tests is
   use Ada.Strings.Unbounded;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Package_Aliases renames Giflib_Tooling.Session_Package_Aliases;
   package State renames Giflib_Tooling.Session_State;
   package Aliases renames Giflib_Tooling.Session_State.Aliases;
   package Bindings renames Giflib_Tooling.Session_State.Bindings;
   package Resolution renames Giflib_Tooling.Session_State.Resolution;
   package Scopes renames Giflib_Tooling.Session_State.Scopes;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Budget_Testing renames Giflib_Tooling.Work_Budgets.Testing;
   use type Package_Aliases.Alias_Outcome;

   procedure Run is
      Object : State.State;
      Profile : Semantics.Callable_Profile;
      Result : State.Relation;
      Budget : Budgets.Budget;
      function Identifier (Value : Positive) return String is
        (Ada.Strings.Fixed.Trim
           (Positive'Image (Value), Ada.Strings.Both));
   begin
      Check.Check
        (not Scopes.Top_Is (Object, State.Program_Scope)
         and then Scopes.Top_End_Name (Object) = "",
         "empty state has total scope-top queries");
      Scopes.Push (Object, State.Program_Scope, "outer");
      Aliases.Add_Implicit (Object, "provider", "alpha.provider", Budget);
      Bindings.Bind_Callable
        (Object, To_Unbounded_String ("sessions"),
         Semantics.No_Session_Depth, "outer_result", "alpha.provider",
         Profile, Budget);
      Scopes.Push (Object, State.Block_Scope);
      Aliases.Add_Implicit (Object, "provider", "beta.provider", Budget);
      Bindings.Bind_Callable
        (Object, To_Unbounded_String ("sessions"),
         Semantics.No_Session_Depth, "inner_result", "beta.provider",
         Profile, Budget);
      Result := Resolution.Visible_Callable
        (Object, "sessions", "provider",
         Semantics.Formal_Type_Vectors.Empty_Vector, Budget);
      Check.Check
        (To_String (Result.Declared_Type) = "inner_result",
         "nested implicit package aliases shadow outer aliases");

      declare
         Cyclic : State.State;
         Cyclic_Budget : Budgets.Budget;
      begin
         Bindings.Bind_Package (Cyclic, "a", Cyclic_Budget, "b");
         Bindings.Bind_Package (Cyclic, "b", Cyclic_Budget, "a");
         Bindings.Bind_Callable
           (Cyclic, To_Unbounded_String ("sessions"),
            Semantics.No_Session_Depth, "incorrect", "b", Profile,
            Cyclic_Budget);
         Result := Resolution.Visible_Callable
           (Cyclic, "sessions", "a",
            Semantics.Formal_Type_Vectors.Empty_Vector, Cyclic_Budget);
         Check.Check
           (Length (Result.Declared_Type) = 0,
            "cyclic package aliases fail conservatively");
      end;

      declare
         Long_Chain : State.State;
         Chain_Budget : Budgets.Budget;
         Resolved : State.Relation;
      begin
         for Index in 1 .. 10 loop
            Bindings.Bind_Package
              (Long_Chain, "p" & Identifier (Index), Chain_Budget,
               (if Index = 10
                then "target" else "p" & Identifier (Index + 1)));
         end loop;
         Bindings.Bind_Callable
           (Long_Chain, To_Unbounded_String ("sessions"),
            Semantics.No_Session_Depth, "result", "target", Profile,
            Chain_Budget);
         Resolved := Resolution.Visible_Callable
           (Long_Chain, "sessions", "p1",
            Semantics.Formal_Type_Vectors.Empty_Vector, Chain_Budget);
         Check.Check
           (To_String (Resolved.Declared_Type) = "result"
            and then not Budget_Testing.Can_Charge
              (Chain_Budget, Budgets.Maximum_Work - 100),
            "qualifier-chain work is charged to the shared resolution budget");
      end;

      declare
         Depth_Budget : Budgets.Budget;
      begin
         declare
            Guard : Budgets.Depth_Guard := Budgets.Enter (Depth_Budget);
            pragma Unreferenced (Guard);
         begin
            Check.Check
              (Budget_Testing.Current_Depth (Depth_Budget) = 1,
               "resolution depth guards enter their scope");
         end;
         Check.Check
           (Budget_Testing.Current_Depth (Depth_Budget) = 0,
            "resolution depth guards leave their scope automatically");
         Budget_Testing.Reach_Depth_Limit (Depth_Budget);
         Check.Check
           (not Budget_Testing.Can_Enter (Depth_Budget),
            "resolution nesting has an enforced depth budget");
      end;

      declare
         Alias_State : State.State;
         Context : Semantics.Type_Classification_Vectors.Vector;
         Outcome : Package_Aliases.Alias_Outcome;
         Alias_Budget : Budgets.Budget;
         Valid : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex ("package short renames provider;");
         Invalid : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex ("package broken renames;");
         procedure Check_Invalid_Target (Text : String) is
            Tokens : constant
              Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
                Source.Lex (Text);
         begin
            Package_Aliases.Add
              (Tokens, Tokens.First_Index, Alias_State, Context, Alias_Budget,
               Outcome);
            Check.Check
              (Outcome = Package_Aliases.Invalid_Renaming,
               "package targets require alternating identifiers and dots");
         end Check_Invalid_Target;
      begin
         Package_Aliases.Add
           (Valid, Valid.First_Index, Alias_State, Context, Alias_Budget,
            Outcome);
         Check.Check
           (Outcome = Package_Aliases.Applied_Renaming,
            "valid package renamings report an applied outcome");
         Package_Aliases.Add
           (Invalid, Invalid.First_Index, Alias_State, Context, Alias_Budget,
            Outcome);
         Check.Check
           (Outcome = Package_Aliases.Invalid_Renaming,
            "malformed package renamings are distinct from declarations");
         Check_Invalid_Target ("package broken renames .provider;");
         Check_Invalid_Target ("package broken renames provider.;");
         Check_Invalid_Target ("package broken renames a..b;");
         Check_Invalid_Target ("package broken renames end;");
         Check_Invalid_Target ("package end renames provider;");
      end;

      declare
         Indexed_State : State.State;
         Indexed_Budget : Budgets.Budget;
      begin
         Scopes.Push (Indexed_State, State.Program_Scope);
         Bindings.Bind_Object
           (Indexed_State, To_Unbounded_String ("item"),
            Semantics.Direct_Session, Indexed_Budget, "outer");
         Scopes.Push (Indexed_State, State.Block_Scope);
         Bindings.Bind_Object
           (Indexed_State, To_Unbounded_String ("item"),
            Semantics.Direct_Session, Indexed_Budget, "inner");
         Result := Resolution.Visible_Relation
           (Indexed_State, State.Object_Binding, "item", Indexed_Budget);
         Check.Check
           (To_String (Result.Declared_Type) = "inner",
            "name indexes select the innermost binding");
         Scopes.Pop (Indexed_State, Indexed_Budget);
         Result := Resolution.Visible_Relation
           (Indexed_State, State.Object_Binding, "item", Indexed_Budget);
         Check.Check
           (To_String (Result.Declared_Type) = "outer",
            "scope exit restores prior linked-index bindings");
      end;
   end Run;
end Giflib_Tooling.Session_Resolution_Tests;
