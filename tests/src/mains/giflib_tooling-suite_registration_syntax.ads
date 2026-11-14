with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Suite_Flow;
with Giflib_Tooling.Suite_Source_Selection;

private package Giflib_Tooling.Suite_Registration_Syntax is
   type Name_Result_Kind is
     (Name_Absent, Name_Found, Name_Ambiguous);
   type Name_Result (Kind : Name_Result_Kind := Name_Absent) is record
      case Kind is
         when Name_Found =>
            Value : Ada.Strings.Unbounded.Unbounded_String;
         when Name_Absent | Name_Ambiguous =>
            null;
      end case;
   end record;

   function Qualified_Test_Unit
     (Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      First : Positive) return Name_Result;

   function Returned_Suite_Name
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Map : Giflib_Tooling.Suite_Flow.Flow_Map) return Name_Result;

end Giflib_Tooling.Suite_Registration_Syntax;
