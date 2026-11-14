with Ada.Strings.Fixed;

with Giflib_Tooling.Session_State.Visibility;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Session_State.Resolution is
   use type Ada.Containers.Count_Type;
   use type Semantics.Session_Depth;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Visibility renames Giflib_Tooling.Session_State.Visibility;

   procedure Charge_Name_Scan
     (Object : State;
      Name : String;
      Passes : Positive;
      Budget : in out Budgets.Budget)
   is
      Count : constant Natural :=
        Name_Candidate_Count (Object, Name, Budget);
   begin
      for Pass in 1 .. Passes loop
         Budgets.Charge_Scan (Budget, Count);
      end loop;
   end Charge_Name_Scan;

   function Visible_Relation
     (Object : State;
      Kind : Relation_Binding_Kind;
      Name : String;
      Budget : in out Budgets.Budget) return Relation is
   begin
      Charge_Name_Scan (Object, Name, 2, Budget);
      return Visibility.Visible_Relation (Object, Kind, Name);
   end Visible_Relation;

   function Visible_Sessions
     (Object : State; Budget : in out Budgets.Budget)
      return Syntax.Name_Vectors.Vector is
   begin
      Budgets.Charge_Scan (Budget, Indexed_Name_Count (Object));
      Budgets.Charge_Scan (Budget, Indexed_Binding_Count (Object));
      return Visibility.Visible_Sessions (Object);
   end Visible_Sessions;

   type Qualifier_Resolution is record
      Resolved : Boolean := False;
      Value : Unbounded_String;
   end record;

   function Resolve_Qualifier
     (Object : State;
      Name : String;
      Budget : in out Budgets.Budget) return Qualifier_Resolution
   is
      Result : Unbounded_String :=
        To_Unbounded_String (Text_Case.Lower (Name));
      Seen : Syntax.Name_Vectors.Vector;
   begin
      loop
         Budgets.Charge_Scan (Budget, Natural (Seen.Length));
         if Syntax.Contains (Seen, To_String (Result)) then
            return (Resolved => False, Value => Null_Unbounded_String);
         end if;
         Seen.Append (Result);
         Budgets.Charge (Budget);
         declare
            Value : constant String := To_String (Result);
            Dot : constant Natural := Ada.Strings.Fixed.Index (Value, ".");
            Head : constant String :=
              (if Dot = 0 then Value else Value (Value'First .. Dot - 1));
            Tail : constant String :=
              (if Dot = 0 then "" else Value (Dot .. Value'Last));
         begin
            Charge_Name_Scan (Object, Head, 2, Budget);
            declare
               Lookup : constant Visibility.Package_Lookup :=
                 Visibility.Visible_Package (Object, Head);
            begin
               case Lookup.Kind is
                  when Visibility.Package_Ambiguous =>
                     return
                       (Resolved => False, Value => Null_Unbounded_String);
                  when Visibility.Package_Found =>
                     Result := Lookup.Target & Tail;
                  when Visibility.Package_Not_Found =>
                     return (Resolved => True, Value => Result);
               end case;
            end;
         end;
      end loop;
   end Resolve_Qualifier;

   function Resolve_Qualified_Name
     (Object : State;
      Name : String;
      Budget : in out Budgets.Budget) return String
   is
      Dot : constant Natural := Ada.Strings.Fixed.Index (Name, ".");
   begin
      if Dot = 0 then
         return Text_Case.Lower (Name);
      end if;
      declare
         Result : constant Qualifier_Resolution :=
           Resolve_Qualifier (Object, Name, Budget);
      begin
         return
           (if Result.Resolved then To_String (Result.Value) else "");
      end;
   end Resolve_Qualified_Name;

   function Visible_Callable
     (Object : State;
      Name : String;
      Qualifier : String;
      Argument_Types : Semantics.Formal_Type_Vectors.Vector;
      Budget : in out Budgets.Budget) return Relation
   is
      Nearest_Scope : Natural := 0;
      Result : Relation;
      Found : Boolean := False;
      type Match_Quality is (No_Match, Unknown_Match, Exact_Match);
      Best_Quality : Match_Quality := No_Match;
      Qualifier_Info : constant Qualifier_Resolution :=
        (if Qualifier = ""
         then (Resolved => True, Value => Null_Unbounded_String)
         else Resolve_Qualifier (Object, Qualifier, Budget));
      Resolved_Qualifier : constant String :=
        To_String (Qualifier_Info.Value);

      function Scope_Matches (Declared : String) return Boolean is
        (Resolved_Qualifier = "" or else Declared = Resolved_Qualifier);

      function Type_Quality
        (Formal : String; Actual : String) return Match_Quality is
         function Is_Known_Numeric (Name : String) return Boolean is
           (Name in
              "integer" | "natural" | "positive" | "float" |
              "long_integer" | "long_float" | "short_integer" |
              "short_float");

         function Is_Known_Incompatible_Literal_Type
           (Name : String; Literal : String) return Boolean is
           ((Literal = "#numeric"
             and then Name in "boolean" | "string" | "character")
            or else
              (Literal = "#boolean"
               and then (Is_Known_Numeric (Name)
                         or else Name in "string" | "character"))
            or else
              (Literal = "#string"
               and then (Is_Known_Numeric (Name)
                         or else Name in "boolean" | "character"))
            or else
              (Literal = "#character"
               and then (Is_Known_Numeric (Name)
                         or else Name in "boolean" | "string")));
      begin
         if Formal = "" or else Actual = "" then
            return Unknown_Match;
         elsif Formal = Actual
           or else
             (Actual = "#numeric" and then Is_Known_Numeric (Formal))
           or else (Actual = "#boolean" and then Formal = "boolean")
           or else (Actual = "#string" and then Formal = "string")
           or else (Actual = "#character" and then Formal = "character")
         then
            return Exact_Match;
         elsif Actual in "#numeric" | "#boolean" | "#string" | "#character"
           and then not Is_Known_Incompatible_Literal_Type (Formal, Actual)
         then
            return Unknown_Match;
         else
            return No_Match;
         end if;
      end Type_Quality;

      function Profile_Quality
        (Profile : Semantics.Callable_Profile) return Match_Quality
      is
         Count : constant Natural := Natural (Argument_Types.Length);
         Result : Match_Quality := Exact_Match;
      begin
         if Count not in Profile.Minimum_Arguments .. Profile.Maximum_Arguments
           or else Argument_Types.Length > Profile.Formal_Types.Length
         then
            return No_Match;
         end if;
         for Index in Argument_Types.First_Index .. Argument_Types.Last_Index loop
            Budgets.Charge (Budget);
            declare
               Quality : constant Match_Quality := Type_Quality
                 (To_String (Profile.Formal_Types (Index)),
                  To_String (Argument_Types (Index)));
            begin
               if Quality = No_Match then
                  return No_Match;
               elsif Quality = Unknown_Match then
                  Result := Unknown_Match;
               end if;
            end;
         end loop;
         return Result;
      end Profile_Quality;

      procedure Consider
        (Value : Relation;
         Scope_Name : String;
         Callable_Profile : Semantics.Callable_Profile;
         Scope_Depth : Natural;
         Continue : in out Boolean) is
      begin
         Budgets.Charge (Budget);
         if Scope_Matches (Scope_Name) then
            declare
               Quality : constant Match_Quality :=
                 Profile_Quality (Callable_Profile);
            begin
               if Quality /= No_Match then
                  if Qualifier = "" and then Found
                    and then Scope_Depth < Nearest_Scope
                  then
                     Continue := False;
                  elsif not Found or else Quality > Best_Quality then
                     Nearest_Scope := Scope_Depth;
                     Found := True;
                     Best_Quality := Quality;
                     Result := Value;
                  elsif Quality = Best_Quality
                    and then Value.Depth < Result.Depth
                  then
                     Result := Value;
                  end if;
               end if;
            end;
         end if;
      end Consider;
   begin
      if not Qualifier_Info.Resolved then
         return (others => <>);
      end if;
      Charge_Name_Scan
        (Object, Name, (if Qualifier = "" then 2 else 1), Budget);
      Visibility.Visit_Visible_Callables
        (Object, Name, Qualified => Qualifier /= "", Process => Consider'Access);
      return Result;
   end Visible_Callable;

   function Visible_Component
     (Object : State;
      Owner_Type : String;
      Name : String;
      Budget : in out Budgets.Budget) return Relation
   is
      Count : constant Natural :=
        Component_Candidate_Count (Object, Owner_Type, Name, Budget);
   begin
      pragma Unreferenced (Count);
      Budgets.Charge (Budget);
      return Visibility.Find_Component (Object, Owner_Type, Name);
   end Visible_Component;
end Giflib_Tooling.Session_State.Resolution;
