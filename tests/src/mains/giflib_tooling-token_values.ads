with Ada.Strings.Unbounded;

private package Giflib_Tooling.Token_Values is
   Invalid_Token : exception;

   type Token_Kind is
     (Identifier, Reserved_Word, Numeric_Literal, String_Literal,
      Character_Literal, Symbol);
   type Token (<>) is private;

   function Create_Identifier
     (Text : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Create_Numeric
     (Text : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Create_Reserved_Word
     (Text : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Create_String
     (Value : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Create_Character
     (Source_Spelling : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Create_Symbol
     (Text : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive) return Token;
   function Kind_Of (Item : Token) return Token_Kind;
   function Text_Of
     (Item : Token) return Ada.Strings.Unbounded.Unbounded_String;
   function Position_Of (Item : Token) return Positive;
private
   type Token (Kind : Token_Kind) is record
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Position : Positive;
   end record;
end Giflib_Tooling.Token_Values;
