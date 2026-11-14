private package Giflib_Tooling.Repository_Capture_Profiles is
   type Capture_Profile is (Complete_Repository, Source_Only);

   procedure Visit
     (Profile : Capture_Profile;
      Include_Directory : not null access procedure
        (Relative_Path : String; Required : Boolean);
      Include_File : not null access procedure
        (Relative_Path : String; Required : Boolean));
end Giflib_Tooling.Repository_Capture_Profiles;
