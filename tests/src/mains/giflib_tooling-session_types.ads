with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.Session_Types is
   use Ada.Strings.Unbounded;

   type Session_Depth (Present : Boolean := False) is record
      case Present is
         when True =>
            Level : Natural;
         when False =>
            null;
      end case;
   end record;
   No_Session_Depth : constant Session_Depth := (Present => False);
   Direct_Session : constant Session_Depth :=
     (Present => True, Level => 0);
   function "<" (Left : Session_Depth; Right : Session_Depth) return Boolean;
   function "<=" (Left : Session_Depth; Right : Session_Depth) return Boolean;
   function Nested (Item : Session_Depth) return Session_Depth;
   function Element (Item : Session_Depth) return Session_Depth;

   type Relation is record
      Depth : Session_Depth := No_Session_Depth;
      Declared_Type : Unbounded_String;
      Related_Type : Unbounded_String;
   end record;

   type Classification_Kind is
     (Type_Relation, Component_Relation, Callable_Relation, Package_Relation);
   type Classification_Relation is record
      Depth : Session_Depth := No_Session_Depth;
      Declared_Type : Unbounded_String;
   end record;
   package Formal_Type_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);
   type Callable_Profile is record
      Text : Unbounded_String;
      Minimum_Arguments : Natural := 0;
      Maximum_Arguments : Natural := 0;
      Formal_Types : Formal_Type_Vectors.Vector;
   end record;
   type Type_Classification (Kind : Classification_Kind) is record
      Name : Unbounded_String;
      case Kind is
         when Type_Relation =>
            Type_Data : Classification_Relation;
            Related_Type : Unbounded_String;
         when Component_Relation =>
            Component_Data : Classification_Relation;
            Owner_Type : Unbounded_String;
         when Callable_Relation =>
            Callable_Data : Classification_Relation;
            Scope_Name : Unbounded_String;
            Profile : Callable_Profile;
         when Package_Relation =>
            Target_Scope : Unbounded_String;
      end case;
   end record;
   package Type_Classification_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Type_Classification);

   function Relation_Of (Item : Type_Classification) return Relation;

end Giflib_Tooling.Session_Types;
