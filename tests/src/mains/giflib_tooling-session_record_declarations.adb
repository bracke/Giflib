with Ada.Strings.Unbounded;

with Giflib_Tooling.Declaration_Analysis;
with Giflib_Tooling.Session_Contexts;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_Type_Indications;

package body Giflib_Tooling.Session_Record_Declarations is
   use Ada.Strings.Unbounded;
   use Semantics;
   use State;
   package Declarations renames Giflib_Tooling.Declaration_Analysis;
   package Contexts renames Giflib_Tooling.Session_Contexts;
   package Indications renames Giflib_Tooling.Session_Type_Indications;
   package Identity renames Giflib_Tooling.Session_Identity;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Record_Index : Positive;
      Owner_Type : String;
      Object : in out State.State;
      Context : in out Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String)
   is
      procedure Add_Component
        (Name : Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive)
      is
         Type_Info : constant Indications.Indication :=
           Indications.Analyze
             (Tokens, Type_First, Type_Last, Object, Budget);
         Declared_Type : constant String :=
           To_String (Type_Info.Declared_Type);
      begin
         Bind_Component
           (Object, Name, Type_Info.Depth,
            Declared_Type => Declared_Type, Owner_Type => Owner_Type,
            Budget => Budget);
         if Is_Context_Component_Level (Object) then
            Contexts.Set_Component
              (Context, Name, Type_Info.Depth,
               To_Unbounded_String (Declared_Type),
               To_Unbounded_String (Owner_Type), Budget);
            if Unit_Scope /= "" then
               declare
                  Qualified_Owner : constant Unbounded_String :=
                    To_Unbounded_String
                      (Identity.Qualified_Declaration
                         (Unit_Scope, Owner_Type));
               begin
                  Bind_Component
                    (Object, Name, Type_Info.Depth,
                     Declared_Type => Declared_Type,
                     Owner_Type => To_String (Qualified_Owner),
                     Budget => Budget);
                  Contexts.Set_Component
                    (Context, Name, Type_Info.Depth,
                     To_Unbounded_String (Declared_Type), Qualified_Owner,
                     Budget);
               end;
            end if;
         end if;
      end Add_Component;
   begin
      if Owner_Type /= "" then
         Budgets.Charge_Scan
           (Budget, Tokens.Last_Index - Record_Index + 1);
         Declarations.Inspect_Record_At
           (Tokens, Record_Index, Add_Component'Access);
      end if;
   end Add;
end Giflib_Tooling.Session_Record_Declarations;
