with Ada.Strings.Unbounded;

private package Giflib_Tooling.Session_State.Visibility is
   type Package_Lookup_Kind is
     (Package_Not_Found, Package_Found, Package_Ambiguous);
   type Package_Lookup is record
      Kind : Package_Lookup_Kind := Package_Not_Found;
      Target : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Visible_Depth
     (Object : State; Kind : Relation_Binding_Kind; Name : String)
      return Semantics.Session_Depth;
   function Visible_Sessions (Object : State) return Syntax.Name_Vectors.Vector;
   function Visible_Relation
     (Object : State; Kind : Relation_Binding_Kind; Name : String)
      return Relation;
   function Visible_Package
     (Object : State; Name : String) return Package_Lookup;
   procedure Visit_Visible_Callables
     (Object : State;
      Name : String;
      Qualified : Boolean;
      Process : not null access procedure
        (Value : Relation;
         Scope_Name : String;
         Profile : Semantics.Callable_Profile;
         Scope_Depth : Natural;
         Continue : in out Boolean));
   function Find_Component
     (Object : State; Owner_Type : String; Name : String) return Relation;
end Giflib_Tooling.Session_State.Visibility;
