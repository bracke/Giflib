with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Contexts;
with Giflib_Tooling.Session_Profiles;
with Giflib_Tooling.Session_State.Aliases;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_Type_Indications;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Session_Callable_Declarations is
   use Ada.Strings.Unbounded;
   use Semantics;
   use State;
   use type Source.Token_Kind;
   package Contexts renames Giflib_Tooling.Session_Contexts;
   package Profiles renames Giflib_Tooling.Session_Profiles;
   package Aliases renames Giflib_Tooling.Session_State.Aliases;
   package Indications renames Giflib_Tooling.Session_Type_Indications;
   package Text_Case renames Giflib_Tooling.Text_Case;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Event : Syntax.Subprogram_Event;
      Object : in out State.State;
      Context : in out Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String := "")
   is
      Index : constant Positive := Event.Token_Index;
      Name_Index : constant Positive := Index + 1;
      Return_Marker : constant Positive :=
        (if Event.Header.Return_Marker.Present
         then Event.Header.Return_Marker.Value else 1);
      Last : constant Positive :=
        (if Event.Header.Declaration_Last.Present
         then Event.Header.Declaration_Last.Value else 1);
   begin
      Budgets.Charge_Scan
        (Budget, Tokens.Last_Index - Index + 1);
      if Source.Image (Tokens (Index)) /= "function"
        or else Name_Index > Tokens.Last_Index
        or else Source.Kind_Of (Tokens (Name_Index)) /= Source.Identifier
        or else not Event.Header.Return_Marker.Present
        or else not Event.Header.Declaration_Last.Present
        or else Last < Return_Marker + 1
      then
         return;
      end if;
      declare
         Type_Info : constant Indications.Indication :=
           Indications.Analyze
             (Tokens, Return_Marker + 1, Last, Object, Budget);
         Profile : constant Callable_Profile :=
           Profiles.Build
             (Tokens, Index, Return_Marker, Last);
         Scope_Name : constant Unbounded_String :=
           To_Unbounded_String
             ((if Unit_Scope /= "" and then Is_Context_Level (Object)
               then Text_Case.Lower (Unit_Scope)
               elsif Is_Empty (Object) then ""
               else Top_End_Name (Object)));
      begin
         if To_String (Scope_Name) /= ""
           and then Profiles.Simple_Name (To_String (Scope_Name)) /=
             To_String (Scope_Name)
         then
            Aliases.Add_Implicit
              (Object, Profiles.Simple_Name (To_String (Scope_Name)),
               To_String (Scope_Name), Budget);
         end if;
         Bind_Callable
           (Object, Source.Text_Of (Tokens (Name_Index)),
            Type_Info.Depth,
            Declared_Type => To_String (Type_Info.Declared_Type),
            Callable_Scope => To_String (Scope_Name),
            Callable_Profile => Profile, Budget => Budget);
         if Is_Context_Level (Object) then
            Contexts.Set_Callable
              (Context, Source.Text_Of (Tokens (Name_Index)), Type_Info.Depth,
               Type_Info.Declared_Type, Scope_Name, Profile, Budget);
         end if;
      end;
   end Add;
end Giflib_Tooling.Session_Callable_Declarations;
