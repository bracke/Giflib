with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.GPR_Lexing is
   type Token_Kind is (Identifier, String_Literal, Symbol);
   type Token is record
      Kind : Token_Kind;
      Text : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Token);

   function Lex (Text : String) return Token_Vectors.Vector;
   function Image (Item : Token) return String;
end Giflib_Tooling.GPR_Lexing;
