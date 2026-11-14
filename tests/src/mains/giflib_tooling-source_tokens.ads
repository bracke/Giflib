with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Token_Values;

private package Giflib_Tooling.Source_Tokens is
   subtype Token_Kind is Giflib_Tooling.Token_Values.Token_Kind;
   Identifier : constant Token_Kind := Giflib_Tooling.Token_Values.Identifier;
   Reserved_Word : constant Token_Kind :=
     Giflib_Tooling.Token_Values.Reserved_Word;
   Numeric_Literal : constant Token_Kind :=
     Giflib_Tooling.Token_Values.Numeric_Literal;
   String_Literal : constant Token_Kind :=
     Giflib_Tooling.Token_Values.String_Literal;
   Character_Literal : constant Token_Kind :=
     Giflib_Tooling.Token_Values.Character_Literal;
   Symbol : constant Token_Kind := Giflib_Tooling.Token_Values.Symbol;
   subtype Token is Giflib_Tooling.Token_Values.Token;
   function "=" (Left, Right : Token) return Boolean
      renames Giflib_Tooling.Token_Values."=";

   package Token_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Token, "=" => "=");
   type Optional_Position (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Positive;
         when False =>
            null;
      end case;
   end record;
   No_Position : constant Optional_Position := (Present => False);
   function Kind_Of (Item : Token) return Token_Kind
      renames Giflib_Tooling.Token_Values.Kind_Of;
   function Text_Of (Item : Token) return Ada.Strings.Unbounded.Unbounded_String
      renames Giflib_Tooling.Token_Values.Text_Of;
   function Position_Of (Item : Token) return Positive
      renames Giflib_Tooling.Token_Values.Position_Of;
   function Image (Item : Token) return String;
   function Image (Items : Token_Vectors.Vector) return String;
end Giflib_Tooling.Source_Tokens;
