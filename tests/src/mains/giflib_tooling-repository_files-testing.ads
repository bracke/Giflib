with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Searches;

package Giflib_Tooling.Repository_Files.Testing is
   procedure Walk_With_Hook
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Giflib_Tooling.Source_Limits.Discovery_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits.Discovery;
      Maximum_Source_Length : Natural :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits.Maximum_Source_Length;
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
end Giflib_Tooling.Repository_Files.Testing;
