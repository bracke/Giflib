with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Call_Analysis;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Transition_Access_Inspection is
   function Has_Protected_Field
     (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Root : Positive;
      Protected_Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
   function Violates
     (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Actual : Positive;
      Protected_Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Has_Protected_Field : Boolean;
      Assignment : Natural;
      Left_Start : Positive;
      Callee : Giflib_Tooling.Call_Analysis.Callee_Result;
      Trusted_Local_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Unit_Name : String;
      Policy_Set : Giflib_Tooling.Transition_Policy.Policy;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
end Giflib_Tooling.Transition_Access_Inspection;
