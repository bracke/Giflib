with Giflib_Tooling.Source_Model;

private package Giflib_Tooling.Token_Patterns is
   function Contains_Code (Text : String; Pattern : String) return Boolean;
   function Contains_Code
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Pattern : String) return Boolean;
end Giflib_Tooling.Token_Patterns;
