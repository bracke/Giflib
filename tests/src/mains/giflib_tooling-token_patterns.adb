with Ada.Containers;

with Giflib_Tooling.Source_Lexing;
with Giflib_Tooling.Source_Tokens;

package body Giflib_Tooling.Token_Patterns is
   use type Ada.Containers.Count_Type;
   package Lexing renames Giflib_Tooling.Source_Lexing;
   package Source renames Giflib_Tooling.Source_Tokens;
   use type Source.Token_Kind;

   function Contains_Tokens
     (Tokens : Source.Token_Vectors.Vector;
      Pattern : Source.Token_Vectors.Vector) return Boolean is
   begin
      if Pattern.Is_Empty or else Tokens.Length < Pattern.Length then
         return False;
      end if;
      for First in Tokens.First_Index .. Tokens.Last_Index loop
         exit when Natural (Tokens.Last_Index - First + 1) <
           Natural (Pattern.Length);
         declare
            Match : Boolean := True;
         begin
            for Offset in 0 .. Natural (Pattern.Length) - 1 loop
               if Source.Kind_Of (Tokens (First + Offset)) /=
                 Source.Kind_Of (Pattern (Pattern.First_Index + Offset))
                 or else Source.Image (Tokens (First + Offset)) /=
                   Source.Image (Pattern (Pattern.First_Index + Offset))
               then
                  Match := False;
                  exit;
               end if;
            end loop;
            if Match then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains_Tokens;

   function Contains_Code (Text : String; Pattern : String) return Boolean is
     (Contains_Tokens (Lexing.Lex (Text), Lexing.Lex (Pattern)));

   function Contains_Code
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Pattern : String) return Boolean
   is
      Found : Boolean := False;
      Pattern_Tokens : constant Source.Token_Vectors.Vector :=
        Lexing.Lex (Pattern);
      procedure Inspect (Tokens : Source.Token_Vectors.Vector) is
      begin
         Found := Contains_Tokens (Tokens, Pattern_Tokens);
      end Inspect;
   begin
      Giflib_Tooling.Source_Model.Inspect_Tokens (Parsed, Inspect'Access);
      return Found;
   end Contains_Code;
end Giflib_Tooling.Token_Patterns;
