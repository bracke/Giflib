with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Repository_Reading;
with Giflib_Tooling.Repository_Traversal;

package body Giflib_Tooling.Repository_Files is
   package Source renames Giflib_Tooling.Source_Limits;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Reading renames Giflib_Tooling.Repository_Reading;
   package Traversal renames Giflib_Tooling.Repository_Traversal;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Walk_With_Hook
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Source.Discovery_Limits;
      Maximum_Source_Length : Natural;
      Before_Inspect : access procedure (Path : String);
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null) is
   begin
      Traversal.Walk
        (Root, Process, Discovery, Maximum_Source_Length, Before_Inspect,
         Cleanup_State);
   end Walk_With_Hook;

   procedure Walk_Opened
     (Root : String;
      Process : not null access procedure
        (Path : String;
         Name : String;
         File : Giflib_Tooling.Repository_Handles.Owner);
      Discovery : Source.Discovery_Limits :=
        Source.Default_Analysis_Limits.Discovery;
      Maximum_Source_Length : Natural :=
        Source.Default_Parsing_Limits.Maximum_Source_Length;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null) is
   begin
      Traversal.Walk
        (Root, Process, Discovery, Maximum_Source_Length, null,
         Cleanup_State);
   end Walk_Opened;

   function Canonical_Root (Root : String) return String is
     (Identity.Canonical_Root (Root));

   function Read_Bounded
     (Path : String; Maximum_Length : Natural) return String is
     (Reading.Read_Bounded (Path, Maximum_Length));

   function Read_Pinned_Bounded
     (File : Giflib_Tooling.Repository_Handles.Owner;
      Maximum_Length : Natural;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String is
     (Reading.Read_Opened_Bounded
        (File, Maximum_Length, Before_Allocate));

   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural) return String is
     (Reading.Read_Bounded_Within (Root, Path, Maximum_Length));

   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Budget : in out Budgets.Budget) return String is
     (Reading.Read_Bounded_Within (Root, Path, Maximum_Length, Budget));

   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Before_Allocate : not null access procedure (Length : Natural))
      return String is
     (Reading.Read_Bounded_Within
        (Root, Path, Maximum_Length,
         Before_Allocate => Before_Allocate));

   function Read_Bounded_Within_With_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_Open : access procedure) return String is
     (Reading.Read_Bounded_Within
        (Root, Path, Maximum_Length, After_Open => After_Open));

   function Read_Bounded_Within_With_Read_Hook
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_First_Read : access procedure) return String is
     (Reading.Read_Bounded_Within
        (Root, Path, Maximum_Length,
         After_First_Read => After_First_Read));
end Giflib_Tooling.Repository_Files;
