with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Searches;

private package Giflib_Tooling.Repository_Files is
   procedure Walk_Opened
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Giflib_Tooling.Source_Limits.Discovery_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits.Discovery;
      Maximum_Source_Length : Natural :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits.Maximum_Source_Length;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null);

   function Canonical_Root (Root : String) return String;

   function Read_Bounded
     (Path : String; Maximum_Length : Natural) return String;
   function Read_Pinned_Bounded
     (File : Giflib_Tooling.Repository_Handles.Owner;
      Maximum_Length : Natural;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String;
   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural) return String;
   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return String;
   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Before_Allocate : not null access procedure (Length : Natural))
      return String;
private
   procedure Walk_With_Hook
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Giflib_Tooling.Source_Limits.Discovery_Limits;
      Maximum_Source_Length : Natural;
      Before_Inspect : access procedure (Path : String);
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null);
   function Read_Bounded_Within_With_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_Open : access procedure) return String;
   function Read_Bounded_Within_With_Read_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_First_Read : access procedure) return String;
end Giflib_Tooling.Repository_Files;
