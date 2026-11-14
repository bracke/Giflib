with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Branch_Expressions;
with Giflib_Tooling.Session_Call_Arguments;
with Giflib_Tooling.Session_Expression_Selections;
with Giflib_Tooling.Session_State.Resolution;
with Giflib_Tooling.Token_Navigation;

package body Giflib_Tooling.Session_Expression_Resolution is
   use Ada.Strings.Unbounded;
   use State;
   use type Source.Token_Kind;
   package Branches renames Giflib_Tooling.Session_Branch_Expressions;
   package Call_Arguments renames Giflib_Tooling.Session_Call_Arguments;
   package Selections renames Giflib_Tooling.Session_Expression_Selections;
   package State_Resolution renames Giflib_Tooling.Session_State.Resolution;
   package Navigation renames Giflib_Tooling.Token_Navigation;

   subtype Resolution_Budget is Budgets.Budget;

   procedure Charge
     (Budget : in out Resolution_Budget; Amount : Natural := 1)
      renames Budgets.Charge;

   function Resolve_With_Budget
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Resolution_Budget) return State.Relation;

   function Is_Selected_Prefix
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Candidate : Positive;
      Budget : in out Resolution_Budget) return Boolean
   is
      Expect_Identifier : Boolean := True;
   begin
      for Cursor in First .. Candidate loop
         Charge (Budget);
         if Expect_Identifier then
            if Source.Kind_Of (Tokens (Cursor)) /= Source.Identifier then
               return False;
            end if;
         elsif Source.Image (Tokens (Cursor)) /= "." then
            return False;
         end if;
         Expect_Identifier := not Expect_Identifier;
      end loop;
      return not Expect_Identifier;
   end Is_Selected_Prefix;

   function Qualifier_Before
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Candidate : Positive;
      Budget : in out Resolution_Budget) return String
   is
      Result : Unbounded_String;
   begin
      if Candidate = First then
         return "";
      end if;
      for Cursor in First .. Candidate - 2 loop
         Charge (Budget);
         Append (Result, Source.Image (Tokens (Cursor)));
      end loop;
      return To_String (Result);
   end Qualifier_Before;

   function Resolve_With_Budget
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Resolution_Budget) return State.Relation
   is
      First_Token : Positive := First;
      Last_Token : Positive := Last;
      Result : Relation;
      Guard : Budgets.Depth_Guard := Budgets.Enter (Budget);
      pragma Unreferenced (Guard);
   begin
      if Tokens.Is_Empty
        or else First not in Tokens.First_Index .. Tokens.Last_Index
        or else Last not in Tokens.First_Index .. Tokens.Last_Index
        or else First > Last
      then
         return (others => <>);
      end if;
      while First_Token < Last_Token loop
         Charge (Budget, Last_Token - First_Token + 1);
         exit when not Navigation.Is_Outer_Group
           (Tokens, First_Token, Last_Token, Budget);
         First_Token := First_Token + 1;
         Last_Token := Last_Token - 1;
      end loop;
      if Source.Image (Tokens (First_Token)) = "if" then
         return Branches.Conditional_Result
           (Tokens, First_Token, Last_Token, Object, Budget,
            Resolve_With_Budget'Access);
      elsif Source.Image (Tokens (First_Token)) = "case" then
         return Branches.Case_Result
           (Tokens, First_Token, Last_Token, Object, Budget,
            Resolve_With_Budget'Access);
      elsif Source.Kind_Of (Tokens (First_Token)) /= Source.Identifier then
         return (others => <>);
      end if;

      Result := State_Resolution.Visible_Relation
        (Object, Object_Binding, Source.Image (Tokens (First_Token)), Budget);
      if Length (Result.Declared_Type) > 0 then
         return Selections.Apply
           (Tokens, Result, First_Token + 1, Last_Token, Object, Budget);
      end if;
      for Candidate in reverse First_Token .. Last_Token loop
         Charge (Budget);
         if Source.Kind_Of (Tokens (Candidate)) = Source.Identifier
           and then Is_Selected_Prefix
             (Tokens, First_Token, Candidate, Budget)
         then
            declare
               Arguments : constant Call_Arguments.Argument_Analysis :=
                 Call_Arguments.Analyze
                   (Tokens, Candidate, Last_Token, Object, Budget,
                    Resolve_With_Budget'Access);
            begin
               if Arguments.Valid then
                  Result := State_Resolution.Visible_Callable
                    (Object, Source.Image (Tokens (Candidate)),
                     Qualifier_Before
                       (Tokens, First_Token, Candidate, Budget),
                     Arguments.Types, Budget);
                  if Length (Result.Declared_Type) > 0 then
                     return Selections.Apply
                       (Tokens, Result, Arguments.Closing + 1,
                        Last_Token, Object, Budget);
                  end if;
               end if;
            end;
         end if;
      end loop;
      Result := State_Resolution.Visible_Relation
        (Object, Type_Binding, Source.Image (Tokens (First_Token)), Budget);
      return
        (if Length (Result.Declared_Type) = 0
         then Relation'(others => <>)
         else Selections.Apply
           (Tokens, Result, First_Token + 1, Last_Token, Object, Budget));
   end Resolve_With_Budget;

   function Resolve
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return State.Relation is
     (Resolve_With_Budget (Tokens, First, Last, Object, Budget));

end Giflib_Tooling.Session_Expression_Resolution;
