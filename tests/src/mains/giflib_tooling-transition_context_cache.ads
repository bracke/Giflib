with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Storage_Budgets;

private package Giflib_Tooling.Transition_Context_Cache is
   package Semantics renames Giflib_Tooling.Session_Types;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Source renames Giflib_Tooling.Source_Units;
   package Names renames Giflib_Tooling.Name_Collections;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   Maximum_Contexts : constant := 64;
   type Cache is limited private;

   function Contains_Clause (Object : Cache; Name : String) return Boolean;
   function Clause_At
     (Object : Cache; Name : String) return Source.Separate_Clause;
   procedure Remember_Clause
     (Object : in out Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget;
      Name : String;
      Clause : Source.Separate_Clause);

   type Context_Lookup (Found : Boolean := False) is record
      case Found is
         when True =>
            Name_Index : Positive;
            Context : Semantics.Type_Classification_Vectors.Vector;
         when False =>
            null;
      end case;
   end record;

   function Load_Deepest_Context
     (Object : Cache;
      Budget : in out Budgets.Budget;
      Prefix : String;
      Target_Type : Identity.Target;
      Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
      return Context_Lookup;
   procedure Remember_Context
     (Object : in out Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget;
      Prefix : String;
      Target_Type : Identity.Target;
      Name : String;
      Context : Semantics.Type_Classification_Vectors.Vector);
private
   package Clause_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Source.Separate_Clause,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "=" => Source."=");
   type Context_Entry is record
      Value : Semantics.Type_Classification_Vectors.Vector;
      Storage_Units : Natural := 0;
   end record;
   package Context_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Context_Entry,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   type Cache is limited record
      Clauses : Clause_Maps.Map;
      Contexts : Context_Maps.Map;
      Context_Order : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   end record;
end Giflib_Tooling.Transition_Context_Cache;
