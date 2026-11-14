with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Transition_Inspection is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   function Violation
     (Statement : Source.Token_Vectors.Vector;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Session_Names : Syntax.Name_Vectors.Vector;
      Policy : Giflib_Tooling.Transition_Policy.Policy;
      Unit_Name : String := "";
      Trusted_Local_Names : Syntax.Name_Vectors.Vector :=
        Syntax.Name_Vectors.Empty_Vector) return Boolean;
   function Analyze
     (Statement : Source.Token_Vectors.Vector;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Session_Names : Syntax.Name_Vectors.Vector;
      Policy : Giflib_Tooling.Transition_Policy.Policy;
      Unit_Name : String;
      Trusted_Local_Names : Syntax.Name_Vectors.Vector;
      Seen : in out Syntax.Name_Vectors.Vector;
      Budget : in out Budgets.Budget) return Boolean;
end Giflib_Tooling.Transition_Inspection;
