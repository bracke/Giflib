with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Events;
with Ada.Strings.Unbounded;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Budgeted_Names;
with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Transition_Storage;

package body Giflib_Tooling.Transition_Declarations is
   use Ada.Strings.Unbounded;
   package Name_Collections renames Giflib_Tooling.Name_Collections;
   package Units renames Giflib_Tooling.Source_Units;
   package Tok renames Giflib_Tooling.Source_Tokens;
   use type Tok.Token_Kind;
   use type Units.Program_Unit_Kind;
   package Policy renames Giflib_Tooling.Transition_Policy;
   package Names renames Giflib_Tooling.Budgeted_Names;
   package Scopes renames Giflib_Tooling.Scope_Analysis;
   use type Scopes.Declaration_Scope;

   procedure Include_Retained
     (Items : in out Name_Collections.Name_Vectors.Vector;
      Name : String;
      Budget : in out Budgets.Budget;
      Storage : in out
        Giflib_Tooling.Validation_Storage_Budgets.Transaction) is
   begin
      if not Names.Contains (Items, Name, Budget) then
         Giflib_Tooling.Transition_Storage.Charge_Name (Storage, Name);
         Budgets.Charge (Budget);
         Items.Append (To_Unbounded_String (Name));
      end if;
   end Include_Retained;

   procedure Collect_Visible
     (Parsed : Source.Parsed_Source;
      Names : in out Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Storage : in out
        Giflib_Tooling.Validation_Storage_Budgets.Transaction)
   is
      procedure Collect (Unit_Info : Units.Program_Unit) is
      begin
         Budgets.Charge (Budget);
         if Unit_Info.Kind = Units.Subprogram_Unit
           and then not Unit_Info.Is_Nested
         then
            Include_Retained
              (Names, To_String (Unit_Info.Name), Budget, Storage);
         end if;
      end Collect;
   begin
      Source.Inspect_Program_Units (Parsed, Collect'Access);
   end Collect_Visible;

   procedure Collect_Types
     (Parsed : Source.Parsed_Source;
      Names : in out Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Storage : in out
        Giflib_Tooling.Validation_Storage_Budgets.Transaction)
   is
      Scope_At : constant Scopes.Declaration_Scope_Vectors.Vector :=
        Scopes.Declaration_Scopes (Parsed, Budget);

      procedure Collect
        (Tokens : Tok.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector)
      is
         pragma Unreferenced (Events);
      begin
         if Natural (Tokens.Length) < 2 then
            return;
         end if;
         for Index in Tokens.First_Index .. Tokens.Last_Index - 1 loop
            Budgets.Charge (Budget);
            if Tok.Image (Tokens (Index)) in "type" | "subtype"
              and then Tok.Kind_Of (Tokens (Index + 1)) = Tok.Identifier
              and then Scope_At (Index) = Scopes.Package_Unit_Declaration
            then
               Include_Retained
                 (Names, Tok.Image (Tokens (Index + 1)), Budget, Storage);
            end if;
         end loop;
      end Collect;
   begin
      Source.Inspect_Syntax (Parsed, Collect'Access);
   end Collect_Types;

   procedure Check
     (Parsed : Source.Parsed_Source;
      Unit_Name : String;
      Policy_Set : Policy.Policy;
      Trusted_Local_Names : Name_Collections.Name_Vectors.Vector;
      Seen_Aliases : in out Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget)
   is
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String,
         Hash => Ada.Strings.Hash,
         Equivalent_Elements => "=");
      Declared_Alias_Identities : Name_Collections.Name_Vectors.Vector;
      Declared_Alias_Names : Name_Collections.Name_Vectors.Vector;
      Declared_Alias_Set : Name_Sets.Set;
      Used_Alias_Set : Name_Sets.Set;

      procedure Inspect (Statement : Tok.Token_Vectors.Vector) is
      begin
         if Natural (Statement.Length) < 4 then
            return;
         end if;
         for Index in Statement.First_Index .. Statement.Last_Index - 2 loop
            Budgets.Charge (Budget);
            if Tok.Image (Statement (Index)) = "package"
              and then Tok.Image (Statement (Index + 1)) /= "body"
              and then Tok.Kind_Of (Statement (Index + 1)) = Tok.Identifier
              and then Policy.Is_Trusted_Qualifier
                (Policy_Set, Tok.Image (Statement (Index + 1)))
            then
               for Marker in Index + 2 .. Statement.Last_Index loop
                  Budgets.Charge (Budget);
                  if Tok.Image (Statement (Marker)) = "renames"
                    and then Marker < Statement.Last_Index
                  then
                     declare
                        Target : Unbounded_String;
                     begin
                        for Cursor in Marker + 1 .. Statement.Last_Index loop
                           Budgets.Charge (Budget);
                           if Tok.Kind_Of (Statement (Cursor)) = Tok.Identifier
                             or else Tok.Image (Statement (Cursor)) = "."
                           then
                              Append (Target, Tok.Image (Statement (Cursor)));
                           else
                              exit;
                           end if;
                        end loop;
                        declare
                           Identity : constant String :=
                             Unit_Name & ":" &
                             Tok.Image (Statement (Index + 1)) & ":" &
                             To_String (Target);
                        begin
                           if not Policy.Is_Reviewed_Alias
                             (Policy_Set, Unit_Name,
                              Tok.Image (Statement (Index + 1)),
                              To_String (Target))
                           then
                              Fail
                                ("package declaration can shadow a reviewed " &
                                 "transition helper: " & Unit_Name);
                           elsif Names.Contains
                             (Declared_Alias_Identities, Identity, Budget)
                             or else Names.Contains
                               (Seen_Aliases, Identity, Budget)
                           then
                              Fail
                                ("duplicate reviewed transition alias: " &
                                 Identity);
                           else
                              Declared_Alias_Identities.Append
                                (To_Unbounded_String (Identity));
                              Declared_Alias_Names.Append
                                (Tok.Text_Of (Statement (Index + 1)));
                              Declared_Alias_Set.Include
                                (Tok.Image (Statement (Index + 1)));
                           end if;
                        end;
                     end;
                     return;
                  elsif Tok.Image (Statement (Marker)) = "is" then
                     Fail
                       ("package declaration can shadow a reviewed transition " &
                        "helper: " & Unit_Name);
                  end if;
               end loop;
            end if;
         end loop;
      end Inspect;

      procedure Inspect_Unit (Unit_Info : Units.Program_Unit) is
         Name : constant String := To_String (Unit_Info.Name);
      begin
         Budgets.Charge (Budget);
         if Unit_Info.Is_Nested
           and then
             (Policy.Is_Trusted_Qualifier (Policy_Set, Name)
              or else Names.Contains (Trusted_Local_Names, Name, Budget))
         then
            Fail
              ("nested declaration can shadow a reviewed transition " &
               "helper: " & Unit_Name);
         end if;
      end Inspect_Unit;

      procedure Find_Used_Aliases
        (Tokens : Tok.Token_Vectors.Vector) is
      begin
         if Natural (Tokens.Length) < 2 then
            return;
         end if;
         for Index in Tokens.First_Index .. Tokens.Last_Index - 1 loop
            Budgets.Charge (Budget);
            if Tok.Kind_Of (Tokens (Index)) = Tok.Identifier
              and then Tok.Image (Tokens (Index + 1)) = "."
              and then
                (Index = Tokens.First_Index
                 or else Tok.Image (Tokens (Index - 1)) /= ".")
              and then Declared_Alias_Set.Contains
                (Tok.Image (Tokens (Index)))
            then
               Used_Alias_Set.Include (Tok.Image (Tokens (Index)));
            end if;
         end loop;
      end Find_Used_Aliases;
   begin
      Source.Inspect_Program_Units (Parsed, Inspect_Unit'Access);
      Source.Scan_Statements (Parsed, Inspect'Access);
      Source.Inspect_Tokens (Parsed, Find_Used_Aliases'Access);
      for Index in Declared_Alias_Identities.First_Index ..
        Declared_Alias_Identities.Last_Index
      loop
         Budgets.Charge (Budget);
         if Used_Alias_Set.Contains
           (To_String (Declared_Alias_Names (Index)))
         then
            Seen_Aliases.Append (Declared_Alias_Identities (Index));
         end if;
      end loop;
   end Check;
end Giflib_Tooling.Transition_Declarations;
