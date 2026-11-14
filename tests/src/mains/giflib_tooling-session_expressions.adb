with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Expression_Resolution;
with Giflib_Tooling.Session_State.Resolution;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Token_Navigation;

package body Giflib_Tooling.Session_Expressions is
   use Ada.Strings.Unbounded;
   use State;
   package Expression_Resolution renames
     Giflib_Tooling.Session_Expression_Resolution;
   package State_Resolution renames Giflib_Tooling.Session_State.Resolution;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Navigation renames Giflib_Tooling.Token_Navigation;
   use type Semantics.Session_Depth;

   function Iterable_Relation
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return Relation
   is
      Loop_Marker : constant Navigation.Optional_Position :=
        Navigation.Before_Semicolon (Tokens, First, "loop", Budget);
   begin
      if not Loop_Marker.Present or else Loop_Marker.Value <= First then
         return (others => <>);
      end if;
      declare
         Collection : constant Relation :=
           Expression_Resolution.Resolve
             (Tokens, First, Loop_Marker.Value - 1, Object, Budget);
         Element_Type : Unbounded_String := Collection.Declared_Type;
         Seen : Syntax.Name_Vectors.Vector;
         Resolved : Boolean := False;
      begin
         if not Collection.Depth.Present or else Collection.Depth.Level = 0 then
            return (others => <>);
         end if;
         loop
            Budgets.Charge_Scan (Budget, Natural (Seen.Length));
            if Syntax.Contains (Seen, To_String (Element_Type)) then
               exit;
            end if;
            Seen.Append (Element_Type);
            declare
               Type_Info : constant Relation :=
                 State_Resolution.Visible_Relation
                   (Object, Type_Binding, To_String (Element_Type), Budget);
            begin
               if Length (Type_Info.Related_Type) = 0 then
                  Resolved := True;
                  exit;
               end if;
               Element_Type := Type_Info.Related_Type;
               if State_Resolution.Visible_Relation
                 (Object, Type_Binding, To_String (Element_Type), Budget).Depth
                   < Collection.Depth
               then
                  Resolved := True;
                  exit;
               end if;
            end;
         end loop;
         if not Resolved then
            return (others => <>);
         end if;
         return
           (Depth => Semantics.Element (Collection.Depth),
            Declared_Type => Element_Type,
            Related_Type => Null_Unbounded_String);
      end;
   end Iterable_Relation;
end Giflib_Tooling.Session_Expressions;
