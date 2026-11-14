with Ada.Strings.Unbounded;

with Giflib_Tooling.Record_Analysis;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Transition_Policy_Call_Data;
with Giflib_Tooling.Transition_Policy_Review_Data;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Transition_Index;
with Giflib_Tooling.Transition_Inspection;
with Giflib_Tooling.Transition_Declarations;
with Giflib_Tooling.Session_Analysis;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Budgeted_Names;
with Giflib_Tooling.Transition_Families;

package body Giflib_Tooling.Transitions is
   use Ada.Strings.Unbounded;
   package Source renames Giflib_Tooling.Source_Model;
   package Records renames Giflib_Tooling.Record_Analysis;
   package Names renames Giflib_Tooling.Source_Names;
   package Policy_Calls renames Giflib_Tooling.Transition_Policy_Call_Data;
   package Policy_Reviews renames Giflib_Tooling.Transition_Policy_Review_Data;
   package Policies renames Giflib_Tooling.Transition_Policy;
   package Unit_Indexing renames Giflib_Tooling.Transition_Index;
   package Inspection renames Giflib_Tooling.Transition_Inspection;
   package Declarations renames Giflib_Tooling.Transition_Declarations;
   package Sessions renames Giflib_Tooling.Session_Analysis;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Budgeted_Names renames Giflib_Tooling.Budgeted_Names;
   package Families renames Giflib_Tooling.Transition_Families;

   function Violation
     (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Protected_Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Unit_Name : String := "") return Boolean
   is (Inspection.Violation
         (Statement, Protected_Fields, Session_Names, Policies.Load,
          Unit_Name));

   function Classified_Fields
     (Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Spec : String;
      Type_Name : String;
      Exempt : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is
      Actual : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Result : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      procedure Inspect (Parsed : Source.Parsed_Source) is
      begin
         Actual := Records.Fields (Parsed, Type_Name);
      end Inspect;
   begin
      Giflib_Tooling.Repository_Source_Cache.Inspect
        (Cached_Sources, Spec, Inspect'Access);
      if Actual.Is_Empty then
         Fail ("cannot derive session fields for " & Type_Name);
      end if;
      for Name of Exempt loop
         if not Giflib_Tooling.Name_Collections.Contains (Actual, To_String (Name)) then
            Fail
              ("stale session-field exemption for " & Type_Name & ": " &
               To_String (Name));
         end if;
      end loop;
      for Name of Actual loop
         if not Giflib_Tooling.Name_Collections.Contains (Exempt, To_String (Name)) then
            Result.Append (Name);
         end if;
      end loop;
      if Natural (Result.Length) + Natural (Exempt.Length) /=
        Natural (Actual.Length)
      then
         Fail ("session fields are not classified exactly once for " & Type_Name);
      end if;
      return Result;
   end Classified_Fields;

   procedure Scan_Family
     (Unit_Index : in out Unit_Indexing.Source_Index;
      Prefix : String;
      Owner : String;
      Target_Type : Identity.Target;
      Policy : Policies.Policy;
      Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Seen_Aliases : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Seen_Calls : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget)
   is
      procedure Inspect_Unit
        (Name : String;
         Parsed : Source.Parsed_Source;
         Context : Semantics.Type_Classification_Vectors.Vector)
      is
         Trusted_Local_Names :
           Giflib_Tooling.Name_Collections.Name_Vectors.Vector;

         procedure Collect_Declarations
           (Source_Name : String;
            Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
            Callable_Names :
              Giflib_Tooling.Name_Collections.Name_Vectors.Vector) is
         begin
            for Type_Name of Type_Names loop
               Budgeted_Names.Include
                 (Trusted_Local_Names, To_String (Type_Name),
                  Budget);
            end loop;
            if Names.In_Family (Source_Name, Prefix) then
               for Callable_Name of Callable_Names loop
                  Budgeted_Names.Include
                    (Trusted_Local_Names, To_String (Callable_Name),
                     Budget);
               end loop;
            end if;
         end Collect_Declarations;

         procedure Inspect
           (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
            Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
         is
         begin
            if Inspection.Analyze
              (Statement, Fields, Session_Names, Policy, Name,
               Trusted_Local_Names, Seen_Calls, Budget)
            then
               Fail
                 ("session state mutation escaped transition owner: " &
                  Name & ": " & Giflib_Tooling.Source_Tokens.Image (Statement));
            end if;
         end Inspect;
      begin
         Unit_Indexing.Inspect_Visible_Sources
           (Unit_Index, Prefix, Name,
            Source.Separate_Clause_Of (Parsed),
            Collect_Declarations'Access);
         Declarations.Check
           (Parsed, Name, Policy, Trusted_Local_Names, Seen_Aliases,
            Budget);
         Sessions.Scan
           (Parsed, Target_Type, Context, Budget, Inspect'Access,
            Unit_Scope => Names.Unit_Name (Name));
      end Inspect_Unit;
   begin
      Unit_Indexing.Scan_Family
        (Unit_Index, Prefix, Owner, Target_Type,
         Inspect_Unit'Access);
   end Scan_Family;

   procedure Validate
     (Repository : aliased in Giflib_Tooling.Repository_Snapshots.Snapshot;
      Cached_Sources : aliased in
        Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : aliased in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget)
   is
      Policy : constant Policies.Policy := Policies.Load;
      Policy_Error : constant String := Policies.Validation_Error (Policy);
      Bound : aliased Unit_Indexing.Resources
        (Repository'Access, Cached_Sources'Access,
         Budget'Access, Storage'Access);
      Unit_Index : Unit_Indexing.Source_Index (Bound'Access);
      Seen_Aliases : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Seen_Calls : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Stale : Unbounded_String;
      procedure Note_Stale (Identity : String) is
      begin
         if Length (Stale) > 0 then
            Append (Stale, ", ");
         end if;
         Append (Stale, Identity);
      end Note_Stale;
      procedure Check_Alias
        (Unit_Name : String; Alias_Name : String; Target : String)
      is
         Identity : constant String :=
           Unit_Name & ":" & Alias_Name & ":" & Target;
      begin
         if not Giflib_Tooling.Name_Collections.Contains (Seen_Aliases, Identity) then
            Note_Stale ("alias " & Identity);
         end if;
      end Check_Alias;
      procedure Check_Global_Call (Callee : String) is
      begin
         if not Giflib_Tooling.Name_Collections.Contains
           (Seen_Calls, "global:" & Callee)
         then
            Note_Stale ("call global:" & Callee);
         end if;
      end Check_Global_Call;
      procedure Check_Family_Call (Unit_Prefix : String; Callee : String) is
      begin
         if not Giflib_Tooling.Name_Collections.Contains
           (Seen_Calls, "family:" & Unit_Prefix & ":" & Callee)
         then
            Note_Stale ("call family:" & Unit_Prefix & ":" & Callee);
         end if;
      end Check_Family_Call;
      procedure Validate_Family
        (Item : Families.Family_Definition)
      is
         Prefix : constant String := To_String (Item.Prefix);
         Type_Name : constant String := To_String (Item.Type_Name);
      begin
         Scan_Family
           (Unit_Index, Prefix, To_String (Item.Owner), Item.Target, Policy,
            Classified_Fields
              (Cached_Sources, To_String (Item.Specification), Type_Name,
               Item.Exempt_Fields),
            Seen_Aliases, Seen_Calls, Budget);
      end Validate_Family;
   begin
      Unit_Indexing.Build (Unit_Index);
      if Policy_Error /= "" then
         Fail (Policy_Error);
      end if;
      Families.Visit (Validate_Family'Access);
      Policy_Reviews.Visit_Reviewed_Aliases (Check_Alias'Access);
      Policy_Calls.Visit_Global_Calls (Check_Global_Call'Access);
      Policy_Calls.Visit_Family_Calls (Check_Family_Call'Access);
      if Length (Stale) > 0 then
         Fail ("stale transition approvals: " & To_String (Stale));
      end if;
   end Validate;
end Giflib_Tooling.Transitions;
