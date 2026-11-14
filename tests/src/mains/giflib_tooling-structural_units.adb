with Ada.Strings.Unbounded;

with Giflib_Tooling.Model_Storage;
with Giflib_Tooling.Structural_Scopes;

package body Giflib_Tooling.Structural_Units is
   use Ada.Strings.Unbounded;
   use Events;
   use Units;
   package Nesting renames Giflib_Tooling.Structural_Scopes;
   use type Nesting.Scope_Kind;

   procedure Derive
     (Events : Structural_Event_Vectors.Vector;
      Units : out Program_Unit_Vectors.Vector;
      Maximum_Units : Natural;
      Budget : in out Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
   is
      Scopes : Nesting.Scope_Stack;
      Subprogram_Depth : Natural := 0;

      procedure Charge is
      begin
         Budgets.Charge (Budget);
      end Charge;

      function Inside_Subprogram return Boolean is
        (Subprogram_Depth > 0);

      procedure Pop_Unit (Name : String) is
         Closed : Nesting.Optional_Scope_Frame;
      begin
         Nesting.Close (Scopes, To_Unbounded_String (Name), Closed);
         if Closed.Present
           and then Closed.Value.Kind = Nesting.Subprogram_Scope
         then
            Subprogram_Depth := Subprogram_Depth - 1;
         end if;
      end Pop_Unit;

      procedure Require_Unit_Capacity is
      begin
         if Natural (Units.Length) >= Maximum_Units then
            raise Input_Error with "program unit limit exceeded";
         end if;
      end Require_Unit_Capacity;
   begin
      Units.Clear;
      for Event of Events loop
         Charge;
         case Event.Kind is
            when Scope_End =>
               Pop_Unit (To_String (Event.Ending_Name));
            when Subprogram_Start =>
               Require_Unit_Capacity;
               Giflib_Tooling.Model_Storage.Charge_Program_Unit
                 (Storage, Event.Subprogram_Name, Event.Header.Profile);
               Units.Append
                 (Program_Unit'
                    (Kind => Subprogram_Unit,
                     Name => Event.Subprogram_Name,
                     Profile => Event.Header.Profile,
                     Is_Nested => Inside_Subprogram,
                     Is_Body => Event.Header.Is_Body));
               if Event.Header.Introduces_Scope then
                  Nesting.Push
                    (Scopes, Nesting.Subprogram_Scope,
                     Event.Subprogram_Name);
                  Subprogram_Depth := Subprogram_Depth + 1;
               end if;
            when Package_Start =>
               if Inside_Subprogram then
                  Require_Unit_Capacity;
                  Giflib_Tooling.Model_Storage.Charge_Program_Unit
                    (Storage, Event.Package_Name, Null_Unbounded_String);
                  Units.Append
                    (Program_Unit'
                       (Kind => Package_Unit, Name => Event.Package_Name,
                        Profile => Null_Unbounded_String,
                        Is_Nested => True,
                        Is_Body => Event.Package_Is_Body));
               end if;
               if Event.Package_Introduces_Scope then
                  Nesting.Push
                    (Scopes, Nesting.Package_Scope, Event.Package_Name);
               end if;
            when Program_Start =>
               Nesting.Push
                 (Scopes, Nesting.Program_Scope, Event.Program_Name);
            when Block_Start =>
               Nesting.Push
                 (Scopes, Nesting.Block_Scope, Event.Block_Name);
            when Record_Start =>
               Nesting.Push
                 (Scopes, Nesting.Record_Scope, Event.Record_Name);
            when Record_End =>
               declare
                  Closed : Nesting.Optional_Scope_Frame;
               begin
                  Nesting.Close_Record (Scopes, Closed);
               end;
            when others =>
               null;
         end case;
      end loop;
   end Derive;

end Giflib_Tooling.Structural_Units;
