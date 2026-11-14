with Giflib_Tooling.Repository_Handles;

private package Giflib_Tooling.Repository_Descriptor_Reading is
   function Read_Bounded
     (File : Giflib_Tooling.Repository_Handles.Owner;
      Maximum_Length : Natural;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String;
end Giflib_Tooling.Repository_Descriptor_Reading;
