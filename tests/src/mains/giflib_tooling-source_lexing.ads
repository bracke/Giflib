with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Source_Lexing is
   package Source renames Giflib_Tooling.Source_Tokens;
   package Limits renames Giflib_Tooling.Source_Limits;

   function Lex
     (Text : String;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Source.Token_Vectors.Vector;
   function Lex
     (Text : String;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Source.Token_Vectors.Vector;
   function Lex_Through
     (Text : String;
      Position : Natural;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Source.Token_Vectors.Vector;
   function Lex_Through
     (Text : String;
      Position : Natural;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Source.Token_Vectors.Vector;
end Giflib_Tooling.Source_Lexing;
