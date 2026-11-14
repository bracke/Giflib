with Giflib_Tooling.Repository_Descriptor_Reading;
with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Repository_Secure_Reading;

package body Giflib_Tooling.Repository_Reading is
   package Descriptor renames
     Giflib_Tooling.Repository_Descriptor_Reading;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Secure renames Giflib_Tooling.Repository_Secure_Reading;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   function Read_Opened_Bounded
     (File : Giflib_Tooling.Repository_Handles.Owner;
      Maximum_Length : Natural;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String is
     (Descriptor.Read_Bounded
        (File, Maximum_Length,
         Before_Allocate => Before_Allocate));

   function Read_Bounded
     (Path : String; Maximum_Length : Natural) return String is
     (Secure.Read_Bounded
        (Path, Required_Root => "", Maximum_Length => Maximum_Length));

   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      After_Open : access procedure := null;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String is
     (Secure.Read_Bounded
        (Path,
         Required_Root => Identity.Canonical_Root (Root),
         Maximum_Length => Maximum_Length,
         After_Open => After_Open,
         After_First_Read => After_First_Read,
         Before_Allocate => Before_Allocate));

   function Read_Bounded_Within
     (Root : String;
      Path : String;
      Maximum_Length : Natural;
      Budget : in out Budgets.Budget) return String
   is
      procedure Charge (Length : Natural) is
      begin
         Budgets.Charge_Scan (Budget, Length);
      end Charge;
   begin
      return Secure.Read_Bounded
        (Path,
         Required_Root => Identity.Canonical_Root (Root),
         Maximum_Length => Maximum_Length,
         Before_Allocate => Charge'Access);
   end Read_Bounded_Within;
end Giflib_Tooling.Repository_Reading;
