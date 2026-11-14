with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_State.Resolution;

package body Giflib_Tooling.Session_Expression_Selections is
   use Ada.Strings.Unbounded;
   use State;
   use type Source.Token_Kind;
   package Resolution renames Giflib_Tooling.Session_State.Resolution;

   function Component_Relation
     (Object : State.State;
      Owner_Type : String;
      Component_Name : String;
      Budget : in out Budgets.Budget) return Relation
   is
      Owner : Unbounded_String := To_Unbounded_String (Owner_Type);
      Seen : Syntax.Name_Vectors.Vector;
   begin
      loop
         Budgets.Charge_Scan (Budget, Natural (Seen.Length));
         if Syntax.Contains (Seen, To_String (Owner)) then
            return (others => <>);
         end if;
         Seen.Append (Owner);
         Budgets.Charge (Budget);
         declare
            Result : constant Relation :=
              Resolution.Visible_Component
                (Object, To_String (Owner), Component_Name, Budget);
            Owner_Info : constant Relation :=
              Resolution.Visible_Relation
                (Object, Type_Binding, To_String (Owner), Budget);
         begin
            if Length (Result.Declared_Type) > 0 then
               return Result;
            elsif Length (Owner_Info.Related_Type) = 0
              or else Owner_Info.Related_Type = Owner
            then
               return (others => <>);
            end if;
            Owner := Owner_Info.Related_Type;
         end;
      end loop;
   end Component_Relation;

   function Apply
     (Tokens : Source.Token_Vectors.Vector;
      Initial : Relation;
      Start : Natural;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return Relation
   is
      Result : Relation := Initial;
      Cursor : Natural := Start;
   begin
      while Cursor + 1 <= Last
        and then Source.Image (Tokens (Positive (Cursor))) = "."
        and then
          (Source.Kind_Of (Tokens (Positive (Cursor + 1))) = Source.Identifier
           or else
             (Source.Kind_Of (Tokens (Positive (Cursor + 1))) =
                Source.Reserved_Word
              and then Source.Image (Tokens (Positive (Cursor + 1))) = "all"))
      loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Positive (Cursor + 1))) /= "all" then
            Result := Component_Relation
              (Object, To_String (Result.Declared_Type),
               Source.Image (Tokens (Positive (Cursor + 1))), Budget);
         end if;
         Cursor := Cursor + 2;
      end loop;
      return Result;
   end Apply;
end Giflib_Tooling.Session_Expression_Selections;
