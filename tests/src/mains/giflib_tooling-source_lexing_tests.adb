with Giflib_Tooling.Source_Tokens;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Token_Lexemes;

package body Giflib_Tooling.Source_Lexing_Tests is
   use Ada.Strings.Unbounded;
   package Tokens renames Giflib_Tooling.Source_Tokens;
   use type Tokens.Token_Kind;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Source renames Giflib_Tooling.Source_Model;
   package Lexemes renames Giflib_Tooling.Token_Lexemes;

   procedure Run is
      Statement_Count : Natural := 0;
      procedure Count (Statement : Tokens.Token_Vectors.Vector) is
         pragma Unreferenced (Statement);
      begin
         Statement_Count := Statement_Count + 1;
      end Count;
      Numeric_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex ("123 16#ff# 1.5e-2 Name1");
      Literal_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex ("""A""""B""");
      Identifier_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex ("Mixed_Case");
      Keyword_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex ("end Good_Name");
      Rebased_Source : constant String (5 .. 12) := "end Name";
      Rebased_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex (Rebased_Source);
      Extreme_Source : constant String
        (Integer'Last .. Integer'Last) := [others => 'X'];
      Extreme_Tokens : constant Tokens.Token_Vectors.Vector :=
        Source.Lex (Extreme_Source);
      Unterminated_Rejected : Boolean := False;
      Invalid_Symbol_Rejected : Boolean := False;

      procedure Expect_Lex_Failure
        (Text : String; Rejected : out Boolean) is
      begin
         Rejected := False;
         declare
            Ignored : constant Tokens.Token_Vectors.Vector := Source.Lex (Text);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Input_Error => Rejected := True;
      end Expect_Lex_Failure;
   begin
      Source.Scan_Statements
        ("X := ';'; Y := "";""; Z := 1;", Count'Access);
      Check.Check
        (Statement_Count = 3,
         "character and string literals do not split statements");
      Check.Check
        (Natural (Numeric_Tokens.Length) = 4
         and then Tokens.Kind_Of (Numeric_Tokens (1)) = Tokens.Numeric_Literal
         and then Tokens.Kind_Of (Numeric_Tokens (2)) = Tokens.Numeric_Literal
         and then Tokens.Kind_Of (Numeric_Tokens (3)) = Tokens.Numeric_Literal
         and then Tokens.Kind_Of (Numeric_Tokens (4)) = Tokens.Identifier,
         "numeric literals are distinct from identifiers");
      Check.Check
        (Natural (Literal_Tokens.Length) = 1
         and then To_String (Tokens.Text_Of (Literal_Tokens.First_Element)) =
           "A""B"
         and then Tokens.Image (Literal_Tokens.First_Element) = """A""""B""",
         "token values and source spelling have distinct literal semantics");
      Check.Check
        (Natural (Identifier_Tokens.Length) = 1
         and then To_String
           (Tokens.Text_Of (Identifier_Tokens.First_Element)) = "mixed_case",
         "lexing preserves identifier normalization");
      Check.Check
        (Natural (Keyword_Tokens.Length) = 2
         and then Tokens.Kind_Of (Keyword_Tokens (1)) = Tokens.Reserved_Word
         and then Tokens.Kind_Of (Keyword_Tokens (2)) = Tokens.Identifier,
         "reserved words are distinct from defining identifiers");
      Check.Check
        (Natural (Rebased_Tokens.Length) = 2
         and then Tokens.Position_Of (Rebased_Tokens (1)) = 1
         and then Tokens.Position_Of (Rebased_Tokens (2)) = 5,
         "token positions are relative to the source value");
      Check.Check
        (Natural (Extreme_Tokens.Length) = 1
         and then Tokens.Position_Of (Extreme_Tokens.First_Element) = 1,
         "lexing accepts a source whose upper bound is Integer'Last");
      Expect_Lex_Failure ("""unterminated", Unterminated_Rejected);
      Expect_Lex_Failure ("_", Invalid_Symbol_Rejected);
      Check.Check
        (Unterminated_Rejected and then Invalid_Symbol_Rejected,
         "lexing rejects unterminated strings and invalid punctuation");
      Check.Check
        (Lexemes.Valid_Identifier ("Good_Name1")
         and then not Lexemes.Valid_Identifier ("A__B")
         and then not Lexemes.Valid_Identifier ("A_"),
         "identifier validation enforces Ada underscore placement");
      Check.Check
        (Lexemes.Valid_Numeric ("123")
         and then Lexemes.Valid_Numeric ("16#ff#")
         and then Lexemes.Valid_Numeric ("1.5e-2")
         and then not Lexemes.Valid_Numeric ("1e+")
         and then not Lexemes.Valid_Numeric ("16#gg#")
         and then not Lexemes.Valid_Numeric ("1__0"),
         "numeric validation rejects incomplete and malformed literals");
   end Run;
end Giflib_Tooling.Source_Lexing_Tests;
