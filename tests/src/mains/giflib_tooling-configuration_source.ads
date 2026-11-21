private package Giflib_Tooling.Configuration_Source is
   type Query_Result is (Assignment_Absent, Assignment_Found, Malformed_Input);

   function Find_Config_Assignment
     (Text : String;
      Key : String;
      Value : String;
      Section : String := "";
      Array_Section : Boolean := False) return Query_Result;
   function Find_Repository_Pin
     (Text : String;
      Crate : String;
      URL : String;
      Commit : String) return Query_Result;
end Giflib_Tooling.Configuration_Source;
