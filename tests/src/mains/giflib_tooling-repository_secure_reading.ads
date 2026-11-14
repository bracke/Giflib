private package Giflib_Tooling.Repository_Secure_Reading is
   function Read_Bounded
     (Path : String;
      Required_Root : String;
      Maximum_Length : Natural;
      After_Open : access procedure := null;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String;
end Giflib_Tooling.Repository_Secure_Reading;
