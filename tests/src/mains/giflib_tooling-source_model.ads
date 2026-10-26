with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Giflib_Tooling.Source_Model is
   use Ada.Strings.Unbounded;

   type Token_Kind is (Identifier, String_Literal, Character_Literal, Symbol);
   type Token is record
      Kind : Token_Kind := Symbol;
      Text : Unbounded_String;
   end record;

   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Token);
   package Name_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);

   function Lex (Text : String) return Token_Vectors.Vector;
   function Image (Item : Token) return String;
   function Image (Items : Token_Vectors.Vector) return String;
   function Lower (Value : String) return String;
   function Contains_Code (Text : String; Pattern : String) return Boolean;
   function Has_GPR_With (Text : String; Project_Path : String) return Boolean;
   function GPR_Attribute_Strings
     (Text : String; Attribute_Name : String) return Name_Vectors.Vector;
   function Has_Config_Assignment
     (Text : String; Key : String; Value : String) return Boolean;
   function Record_Fields
     (Text : String; Type_Name : String) return Name_Vectors.Vector;

   procedure Scan_Statements
     (Text : String;
      Process : not null access procedure (Statement : Token_Vectors.Vector));

   function Contains (Names : Name_Vectors.Vector; Name : String) return Boolean;
   function Join_Callee
     (Statement : Token_Vectors.Vector; Open_Paren : Positive) return String;
   function Enclosing_Callee
     (Statement : Token_Vectors.Vector; Actual : Positive) return String;
end Giflib_Tooling.Source_Model;
