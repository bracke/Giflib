with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Session_Types;

private package Giflib_Tooling.Session_State is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   type Scope_Kind is
     (Program_Scope, Package_Scope, Block_Scope, Loop_Scope,
      Handler_Scope, Return_Scope, Accept_Scope, Profile_Scope,
      Type_Profile_Scope, Record_Scope);
   type Binding_Kind is
     (Object_Binding, Type_Binding, Component_Binding, Callable_Binding,
      Package_Binding);
   subtype Relation_Binding_Kind is Binding_Kind
     range Object_Binding .. Type_Binding;
   subtype Relation is Semantics.Relation;
   type State is private;
private
   use Ada.Strings.Unbounded;
   type Scope is record
      Kind : Scope_Kind;
      End_Name : Unbounded_String;
   end record;
   package Scope_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Scope);
   type Package_Resolution is
     (Explicit_Target, Implicit_Target, Ambiguous_Target);
   type Binding_Data (Kind : Binding_Kind := Object_Binding) is record
      case Kind is
         when Object_Binding =>
            Object_Name : Unbounded_String;
            Object_Relation : Relation;
         when Type_Binding =>
            Type_Info : Semantics.Type_Classification
              (Semantics.Type_Relation);
         when Component_Binding =>
            Component_Info : Semantics.Type_Classification
              (Semantics.Component_Relation);
         when Callable_Binding =>
            Callable_Info : Semantics.Type_Classification
              (Semantics.Callable_Relation);
         when Package_Binding =>
            Package_Info : Semantics.Type_Classification
              (Semantics.Package_Relation);
            Resolution : Package_Resolution;
      end case;
   end record;
   type Optional_Binding_Index (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Positive := 1;
         when False =>
            null;
      end case;
   end record;
   type Binding (Kind : Binding_Kind := Object_Binding) is record
      Scope_Depth : Natural;
      Prior_Name : Optional_Binding_Index;
      Data : Binding_Data (Kind);
      case Kind is
         when Component_Binding =>
            Prior_Component : Optional_Binding_Index;
         when others =>
            null;
      end case;
   end record;
   package Binding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Binding);
   package Binding_Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String,
      Element_Type => Positive,
      Hash => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   type State is record
      Scopes : Scope_Vectors.Vector;
      Bindings : Binding_Vectors.Vector;
      Name_Indices : Binding_Index_Maps.Map;
      Component_Indices : Binding_Index_Maps.Map;
      Context_Depth : Natural := 0;
   end record;
   function Component_Key (Owner_Type : String; Name : String) return String;
   function Indexed_Name_Count (Object : State) return Natural;
   function Indexed_Binding_Count (Object : State) return Natural;
   procedure Index_Binding (Object : in out State; Index : Positive);
   function Unindex_Binding
     (Object : in out State; Index : Positive) return Boolean;
   function Latest_Name_Index
     (Object : State; Name : String) return Optional_Binding_Index;
   function Latest_Component_Index
     (Object : State; Owner_Type : String; Name : String)
      return Optional_Binding_Index;
   function Name_Candidate_Count
     (Object : State;
      Name : String;
      Budget : in out Budgets.Budget) return Natural;
   function Component_Candidate_Count
     (Object : State;
      Owner_Type : String;
      Name : String;
      Budget : in out Budgets.Budget) return Natural;
   function Name_Of (Item : Binding) return String;
   function Relation_Of (Item : Binding) return Relation;
end Giflib_Tooling.Session_State;
