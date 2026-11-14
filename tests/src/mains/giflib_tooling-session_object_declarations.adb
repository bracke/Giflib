with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_Type_Indications;

package body Giflib_Tooling.Session_Object_Declarations is
   use Ada.Strings.Unbounded;
   use State;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;
   use type Source.Token_Kind;
   package Indications renames Giflib_Tooling.Session_Type_Indications;

   function In_Type_Discriminants
     (Tokens : Source.Token_Vectors.Vector;
      Statement : Source.Token_Vectors.Vector;
      Colon : Positive) return Boolean
   is
      Saw_Type : Boolean := False;
   begin
      if Statement.Is_Empty then
         return False;
      end if;
      for Cursor in Statement.First_Index .. Statement.Last_Index loop
         exit when Source.Position_Of (Statement (Cursor)) >=
           Source.Position_Of (Tokens (Colon));
         if Source.Image (Statement (Cursor)) in "type" | "subtype" then
            Saw_Type := True;
         elsif Source.Image (Statement (Cursor)) = "is" then
            Saw_Type := False;
         end if;
      end loop;
      return Saw_Type;
   end In_Type_Discriminants;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Statement : Source.Token_Vectors.Vector;
      Colon : Positive;
      Object : in out State.State;
      Budget : in out Budgets.Budget)
   is
      Last : Natural := Colon + 1;
      First_Name : Positive := Colon - 1;
      Cursor : Positive;
      Session_Nesting : State.Semantics.Session_Depth :=
        State.Semantics.No_Session_Depth;
      Declared_Type : Unbounded_String;
   begin
      Budgets.Charge_Scan (Budget, Tokens.Last_Index - Colon + 1);
      Budgets.Charge_Scan (Budget, Natural (Statement.Length));
      if Colon = Tokens.First_Index
        or else Source.Kind_Of (Tokens (Colon - 1)) /= Source.Identifier
        or else (Top_Is (Object, Type_Profile_Scope)
                 or else Top_Is (Object, Record_Scope))
        or else In_Type_Discriminants (Tokens, Statement, Colon)
        or else (Colon < Tokens.Last_Index
                 and then Source.Image (Tokens (Colon + 1)) in
                   "declare" | "begin" | "loop")
      then
         return;
      end if;
      while Last <= Tokens.Last_Index
        and then Source.Image (Tokens (Last)) not in
          ";" | ")" | ":=" | "renames"
      loop
         Last := Last + 1;
      end loop;
      if Last > Colon + 1 then
         declare
            Type_Info : constant Indications.Indication :=
              Indications.Analyze
                (Tokens, Colon + 1, Last - 1, Object, Budget);
         begin
            Session_Nesting := Type_Info.Depth;
            Declared_Type := Type_Info.Declared_Type;
         end;
      end if;
      while First_Name >= Tokens.First_Index + 2
        and then Source.Image (Tokens (First_Name - 1)) = ","
        and then Source.Kind_Of (Tokens (First_Name - 2)) = Source.Identifier
      loop
         First_Name := First_Name - 2;
      end loop;
      Cursor := First_Name;
      while Cursor < Colon loop
         if Source.Kind_Of (Tokens (Cursor)) = Source.Identifier then
            Bind_Object
              (Object, Source.Text_Of (Tokens (Cursor)), Session_Nesting,
               Budget => Budget,
               Declared_Type => To_String (Declared_Type));
         end if;
         Cursor := Cursor + 1;
      end loop;
   end Add;
end Giflib_Tooling.Session_Object_Declarations;
