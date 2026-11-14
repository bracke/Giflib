with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Expressions;
with Giflib_Tooling.Session_Object_Declarations;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_Type_Declarations;
with Giflib_Tooling.Token_Navigation;

package body Giflib_Tooling.Session_Lexical_Events is
   use Source;
   use type Source.Token_Kind;
   use State;
   package Expressions renames Giflib_Tooling.Session_Expressions;
   package Object_Declarations renames
     Giflib_Tooling.Session_Object_Declarations;
   package Type_Declarations renames
     Giflib_Tooling.Session_Type_Declarations;
   package Navigation renames Giflib_Tooling.Token_Navigation;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;

   procedure Pop_Handler
     (Object : in out State.State; Budget : in out Budgets.Budget) is
   begin
      if Top_Is (Object, Handler_Scope) then
         Pop (Object, Budget);
      end if;
   end Pop_Handler;

   procedure Apply
     (Tokens : Token_Vectors.Vector;
      Statement : Token_Vectors.Vector;
      Index : Positive;
      Object : in out State.State;
      Discovered_Context : in out
        Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String) is
   begin
      if Image (Tokens (Index)) = "for"
        and then Index + 2 <= Tokens.Last_Index
        and then Kind_Of (Tokens (Index + 1)) = Identifier
        and then Image (Tokens (Index + 2)) in "in" | "of"
        and then Navigation.Before_Semicolon
          (Tokens, Index + 2, "loop", Budget).Present
      then
         Push (Object, Loop_Scope);
         declare
            Item : constant State.Relation :=
              (if Image (Tokens (Index + 2)) = "of"
               then Expressions.Iterable_Relation
                 (Tokens, Index + 3, Object, Budget)
               else (others => <>));
         begin
            Bind_Object
              (Object, Text_Of (Tokens (Index + 1)), Item.Depth,
               Budget => Budget,
               Declared_Type => Ada.Strings.Unbounded.To_String
                 (Item.Declared_Type));
         end;
      elsif Image (Tokens (Index)) = "when"
        and then Index + 2 <= Tokens.Last_Index
        and then Kind_Of (Tokens (Index + 1)) = Identifier
        and then Image (Tokens (Index + 2)) = ":"
      then
         Pop_Handler (Object, Budget);
         Push (Object, Handler_Scope);
      elsif Image (Tokens (Index)) = "return"
        and then Index + 2 <= Tokens.Last_Index
        and then Kind_Of (Tokens (Index + 1)) = Identifier
        and then Image (Tokens (Index + 2)) = ":"
        and then Navigation.Before_Semicolon
          (Tokens, Index + 2, "do", Budget).Present
      then
         Push (Object, Return_Scope);
      elsif Image (Tokens (Index)) = "accept" then
         if Navigation.Before_Outer_Semicolon
           (Tokens, Index + 1, "do", Budget).Present
         then
            Push
              (Object, Accept_Scope,
               (if Index < Tokens.Last_Index
                  and then Kind_Of (Tokens (Index + 1)) = Identifier
                then Image (Tokens (Index + 1)) else ""));
         else
            Push (Object, Profile_Scope);
         end if;
      elsif Image (Tokens (Index)) = "entry"
        and then Index < Tokens.Last_Index
        and then Kind_Of (Tokens (Index + 1)) = Identifier
      then
         Push (Object, Profile_Scope);
      elsif Image (Tokens (Index)) = "type" then
         Type_Declarations.Add
           (Tokens, Index, Object, Discovered_Context, Budget, Unit_Scope);
         declare
            Is_Marker : constant Navigation.Optional_Position :=
              Navigation.Before_Outer_Semicolon
                (Tokens, Index + 2, "is", Budget);
            Has_Discriminants : Boolean := False;
         begin
            if Is_Marker.Present and then Is_Marker.Value > Index + 2 then
               for Cursor in Index + 2 .. Is_Marker.Value - 1 loop
                  Has_Discriminants := Has_Discriminants
                    or else Image (Tokens (Cursor)) = "(";
               end loop;
            end if;
            if Has_Discriminants then
               Push (Object, Type_Profile_Scope);
            end if;
         end;
      elsif Image (Tokens (Index)) = "subtype" then
         Type_Declarations.Add
           (Tokens, Index, Object, Discovered_Context, Budget, Unit_Scope);
      elsif Image (Tokens (Index)) = "is"
        and then not Is_Empty (Object)
        and then Top_Is (Object, Type_Profile_Scope)
      then
         Pop (Object, Budget);
      elsif Image (Tokens (Index)) = ":" then
         Object_Declarations.Add
           (Tokens, Statement, Index, Object, Budget);
      end if;
   end Apply;

   procedure Finish_Statement
     (Object : in out State.State;
      Parenthesis_Depth : Natural;
      Budget : in out Budgets.Budget) is
   begin
      if Top_Is (Object, Profile_Scope)
        and then Parenthesis_Depth = 0
      then
         Pop (Object, Budget);
      end if;
   end Finish_Statement;
end Giflib_Tooling.Session_Lexical_Events;
