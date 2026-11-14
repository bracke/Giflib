package body Giflib_Tooling.Repository_Files.Testing is
   package Source renames Giflib_Tooling.Source_Limits;
   procedure Walk_With_Hook
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Source.Discovery_Limits :=
        Source.Default_Analysis_Limits.Discovery;
      Maximum_Source_Length : Natural :=
        Source.Default_Parsing_Limits.Maximum_Source_Length;
      Before_Inspect : access procedure (Path : String);
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null)
   is
   begin
      Repository_Files.Walk_With_Hook
        (Root, Process, Discovery, Maximum_Source_Length, Before_Inspect,
         Cleanup_State);
   end Walk_With_Hook;

   function Read_Bounded_Within_With_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_Open : access procedure) return String
   is
     (Repository_Files.Read_Bounded_Within_With_Hook
        (Root, Path, Maximum_Length, After_Open));

   function Read_Bounded_Within_With_Read_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_First_Read : access procedure) return String
   is
     (Repository_Files.Read_Bounded_Within_With_Read_Hook
        (Root, Path, Maximum_Length, After_First_Read));
end Giflib_Tooling.Repository_Files.Testing;
