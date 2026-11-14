with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Repository_Handles;

private package Giflib_Tooling.Repository_Reading is
   function Read_Opened_Bounded
     (File : Giflib_Tooling.Repository_Handles.Owner;
      Maximum_Length : Natural;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String;
   function Read_Bounded
     (Path : String; Maximum_Length : Natural) return String;
   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_Open : access procedure := null;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String;
   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return String;
end Giflib_Tooling.Repository_Reading;
