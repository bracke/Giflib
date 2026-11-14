with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Call_Analysis;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Transition_Call_Inspection is
   function Callee
     (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Actual : Positive) return Giflib_Tooling.Call_Analysis.Callee_Result;
   function In_Subprogram_Profile
     (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Actual : Positive;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
   procedure Record_Allowed
     (Callee : Giflib_Tooling.Call_Analysis.Callee_Result;
      Unit_Name : String;
      Policy_Set : Giflib_Tooling.Transition_Policy.Policy;
      Seen : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Transition_Call_Inspection;
