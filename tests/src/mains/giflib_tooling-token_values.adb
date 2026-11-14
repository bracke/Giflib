with Ada.Characters.Handling;

with Project_Tools.Ada_Source;

with Giflib_Tooling.Token_Lexemes;

package body Giflib_Tooling.Token_Values is
   use Ada.Strings.Unbounded;

   package Lexemes renames Giflib_Tooling.Token_Lexemes;

   procedure Require (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Invalid_Token with Message;
      end if;
   end Require;

   function Normalized (Text : Unbounded_String) return Unbounded_String is
      Result : String := To_String (Text);
   begin
      for Character of Result loop
         Character := Ada.Characters.Handling.To_Lower (Character);
      end loop;
      return To_Unbounded_String (Result);
   end Normalized;

   function Make
     (Kind : Token_Kind;
      Text : Unbounded_String;
      Position : Positive) return Token is
     ((Kind => Kind, Text => Text, Position => Position));

   function Create_Identifier
     (Text : Unbounded_String; Position : Positive) return Token
   is
      Value : constant String := To_String (Text);
   begin
      Require
        (Lexemes.Valid_Identifier (Value)
         and then not Project_Tools.Ada_Source.Is_Ada_Reserved_Word (Value),
         "invalid identifier token representation");
      return Make (Identifier, Normalized (Text), Position);
   end Create_Identifier;

   function Create_Reserved_Word
     (Text : Unbounded_String; Position : Positive) return Token
   is
      Value : constant String := To_String (Text);
   begin
      Require
        (Lexemes.Valid_Identifier (Value)
         and then Project_Tools.Ada_Source.Is_Ada_Reserved_Word (Value),
         "invalid reserved-word token representation");
      return Make (Reserved_Word, Normalized (Text), Position);
   end Create_Reserved_Word;

   function Create_Numeric
     (Text : Unbounded_String; Position : Positive) return Token
   is
      Value : constant String := To_String (Text);
   begin
      Require
        (Lexemes.Valid_Numeric (Value),
         "invalid numeric token representation");
      return Make (Numeric_Literal, Normalized (Text), Position);
   end Create_Numeric;

   function Create_String
     (Value : Unbounded_String; Position : Positive) return Token is
     (Make (String_Literal, Value, Position));

   function Create_Character
     (Source_Spelling : Unbounded_String; Position : Positive) return Token
   is
      Value : constant String := To_String (Source_Spelling);
   begin
      Require
        (Value'Length = 3
         and then Value (Value'First) = '''
         and then Value (Value'Last) = ''',
         "invalid character token representation");
      return Make (Character_Literal, Source_Spelling, Position);
   end Create_Character;

   function Create_Symbol
     (Text : Unbounded_String; Position : Positive) return Token
   is
      Value : constant String := To_String (Text);
      Valid : constant Boolean :=
        (Value'Length = 1
         and then Value (Value'First) in
           '&' | ''' | '(' | ')' | '*' | '+' | ',' | '-' | '.' | '/' | ':' |
           ';' | '<' | '=' | '>' | '[' | ']' | '|' | '@')
        or else Value in ":=" | "=>" | ".." | "<>";
   begin
      Require (Valid, "invalid symbol token representation");
      return Make (Symbol, Text, Position);
   end Create_Symbol;

   function Kind_Of (Item : Token) return Token_Kind is (Item.Kind);
   function Text_Of (Item : Token) return Unbounded_String is (Item.Text);
   function Position_Of (Item : Token) return Positive is (Item.Position);
end Giflib_Tooling.Token_Values;
