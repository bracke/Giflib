with Giflib_Tooling.Work_Budgets;

package Giflib_Tooling.Session_State.Resolution is
   package Budgets renames Giflib_Tooling.Work_Budgets;

   function Visible_Relation
     (Object : State;
      Kind : Relation_Binding_Kind;
      Name : String;
      Budget : in out Budgets.Budget) return Relation;
   function Resolve_Qualified_Name
     (Object : State;
      Name : String;
      Budget : in out Budgets.Budget) return String;
   function Visible_Sessions
     (Object : State; Budget : in out Budgets.Budget)
      return Syntax.Name_Vectors.Vector;
   function Visible_Callable
     (Object : State;
      Name : String;
      Qualifier : String;
      Argument_Types : Semantics.Formal_Type_Vectors.Vector;
      Budget : in out Budgets.Budget) return Relation;
   function Visible_Component
     (Object : State;
      Owner_Type : String;
      Name : String;
      Budget : in out Budgets.Budget) return Relation;
end Giflib_Tooling.Session_State.Resolution;
