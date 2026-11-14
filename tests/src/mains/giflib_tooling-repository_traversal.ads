with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Repository_Handles;
with Giflib_Tooling.Repository_Searches;

private package Giflib_Tooling.Repository_Traversal is
   procedure Walk
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
end Giflib_Tooling.Repository_Traversal;
