with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Budgeted_Names is
   function Contains
     (Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Name : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean;
   procedure Include
     (Names : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Name : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget);
end Giflib_Tooling.Budgeted_Names;
