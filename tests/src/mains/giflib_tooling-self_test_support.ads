private package Giflib_Tooling.Self_Test_Support is
   procedure Check (Condition : Boolean; Message : String);
   procedure Skip (Message : String);
   function Position_After (Text : String; Fragment : String) return Natural;
end Giflib_Tooling.Self_Test_Support;
