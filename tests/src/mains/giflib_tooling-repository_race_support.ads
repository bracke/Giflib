private package Giflib_Tooling.Repository_Race_Support is
   procedure With_Fixture
     (Name : String;
      Process : not null access procedure
        (Root : String; Inside : String; Link_Command : String));

   procedure Create_Link
     (Directory : String;
      Link_Command : String;
      Target : String;
      Name : String);
end Giflib_Tooling.Repository_Race_Support;
