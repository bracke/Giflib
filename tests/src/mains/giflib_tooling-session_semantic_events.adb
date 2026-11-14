with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Callable_Declarations;
with Giflib_Tooling.Session_Lexical_Events;
with Giflib_Tooling.Session_Package_Aliases;
with Giflib_Tooling.Session_Profiles;
with Giflib_Tooling.Session_Record_Declarations;
with Giflib_Tooling.Session_State.Aliases;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;

package body Giflib_Tooling.Session_Semantic_Events is
   use Ada.Strings.Unbounded;
   use Source;
   use Syntax;
   use Semantics;
   use State;
   package Callable_Declarations renames
     Giflib_Tooling.Session_Callable_Declarations;
   package Lexical_Events renames Giflib_Tooling.Session_Lexical_Events;
   package Package_Aliases renames Giflib_Tooling.Session_Package_Aliases;
   package Profiles renames Giflib_Tooling.Session_Profiles;
   package Record_Declarations renames
     Giflib_Tooling.Session_Record_Declarations;
   package Aliases renames Giflib_Tooling.Session_State.Aliases;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;

   procedure Initialize
     (Object : in out State.State;
      Target_Type : Identity.Target;
      Budget : in out Budgets.Budget;
      Initial_Context : Type_Classification_Vectors.Vector)
   is
      Simple_Type : constant String := Identity.Simple_Name (Target_Type);
      Qualified_Type : constant String := Identity.Qualified_Name (Target_Type);
   begin
      Budgets.Charge_Scan (Budget, Natural (Initial_Context.Length));
      Bind_Type
        (Object, To_Unbounded_String (Simple_Type), Direct_Session,
         Budget => Budget, Declared_Type => Simple_Type);
      if Qualified_Type /= "" then
         Bind_Type
           (Object, To_Unbounded_String (Qualified_Type), Direct_Session,
            Declared_Type => Qualified_Type, Budget => Budget);
      end if;
      for Item of Initial_Context loop
         Budgets.Charge (Budget);
         if Item.Kind /= Type_Relation
           or else not Identity.Matches
             (Target_Type, To_String (Item.Name))
         then
            case Item.Kind is
               when Callable_Relation =>
                  if To_String (Item.Scope_Name) /= ""
                    and then
                      Profiles.Simple_Name (To_String (Item.Scope_Name)) /=
                        To_String (Item.Scope_Name)
                  then
                     Aliases.Add_Implicit
                       (Object,
                        Profiles.Simple_Name (To_String (Item.Scope_Name)),
                        To_String (Item.Scope_Name), Budget);
                  end if;
                  Bind_Callable
                    (Object, Item.Name, Item.Callable_Data.Depth,
                     To_String (Item.Callable_Data.Declared_Type),
                     To_String (Item.Scope_Name), Item.Profile, Budget);
               when Type_Relation =>
                  Bind_Type
                    (Object, Item.Name, Item.Type_Data.Depth,
                     To_String (Item.Type_Data.Declared_Type),
                     Budget, To_String (Item.Related_Type));
               when Component_Relation =>
                  Bind_Component
                    (Object, Item.Name, Item.Component_Data.Depth,
                     To_String (Item.Component_Data.Declared_Type),
                     To_String (Item.Owner_Type), Budget);
               when Package_Relation =>
                  Bind_Package
                    (Object, To_String (Item.Name), Budget,
                     To_String (Item.Target_Scope));
            end case;
         end if;
      end loop;
   end Initialize;

   procedure Apply
     (Tokens : Token_Vectors.Vector;
      Statement : Token_Vectors.Vector;
      Index : Positive;
      Event : Structural_Event;
      Object : in out State.State;
      Discovered_Context : in out Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String)
   is
      procedure Pop_Handler is
      begin
         if Top_Is (Object, Handler_Scope) then
            Pop (Object, Budget);
         end if;
      end Pop_Handler;
   begin
      case Event.Kind is
         when Scope_End =>
            Pop_Handler;
            if not Is_Empty (Object)
              and then
                (Length (Event.Ending_Name) = 0
                 or else To_String (Event.Ending_Name) = Top_End_Name (Object)
                 or else
                   (Top_Is (Object, Block_Scope)
                    and then Top_End_Name (Object) = ""))
            then
               Pop (Object, Budget);
            end if;
            return;
         when Record_End =>
            if Top_Is (Object, Record_Scope) then
               Pop (Object, Budget);
            end if;
            return;
         when Loop_End =>
            if Top_Is (Object, Loop_Scope) then
               Pop (Object, Budget);
            end if;
            return;
         when Return_End =>
            if Top_Is (Object, Return_Scope) then
               Pop (Object, Budget);
            end if;
            return;
         when Control_End =>
            return;
         when Subprogram_Start =>
            Callable_Declarations.Add
              (Tokens, Event, Object, Discovered_Context, Budget, Unit_Scope);
            Push
              (Object,
               (if Event.Header.Introduces_Scope
                then Program_Scope else Profile_Scope),
               (if Event.Header.Introduces_Scope
                then To_String (Event.Subprogram_Name) else ""));
            return;
         when Package_Start =>
            if not Event.Package_Is_Body then
               declare
                  Outcome : Package_Aliases.Alias_Outcome;
               begin
                  Package_Aliases.Add
                    (Tokens, Index, Object, Discovered_Context, Budget,
                     Outcome);
                  case Outcome is
                     when Package_Aliases.Not_A_Renaming =>
                        Bind_Package
                          (Object, To_String (Event.Package_Name), Budget);
                     when Package_Aliases.Applied_Renaming |
                       Package_Aliases.Invalid_Renaming =>
                        null;
                  end case;
               end;
            end if;
            if Event.Package_Introduces_Scope then
               Push
                 (Object, Package_Scope,
                  To_String (Event.Package_Name));
            end if;
            return;
         when Program_Start =>
            Push (Object, Program_Scope, To_String (Event.Program_Name));
            return;
         when Block_Start =>
            Push (Object, Block_Scope, To_String (Event.Block_Name));
            return;
         when Record_Start =>
            Push (Object, Record_Scope, To_String (Event.Record_Name));
            Record_Declarations.Add
              (Tokens, Index, To_String (Event.Record_Name), Object,
               Discovered_Context, Budget, Unit_Scope);
            return;
         when No_Structural_Event =>
            null;
      end case;

      Lexical_Events.Apply
        (Tokens, Statement, Index, Object, Discovered_Context, Budget,
         Unit_Scope);
   end Apply;

   procedure Finish_Statement
     (Object : in out State.State;
      Parenthesis_Depth : Natural;
      Budget : in out Budgets.Budget)
      renames Lexical_Events.Finish_Statement;
end Giflib_Tooling.Session_Semantic_Events;
