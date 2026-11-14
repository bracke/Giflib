with Ada.Containers;
with Ada.Strings.Unbounded;

with Giflib_Tooling.GPR_Lexing;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.GPR_Analysis is
   use type Ada.Containers.Count_Type;
   package Lexing renames Giflib_Tooling.GPR_Lexing;
   package Text_Case renames Giflib_Tooling.Text_Case;
   use type Lexing.Token_Kind;

   function Has_With (Text : String; Project_Path : String) return Boolean
   is
      Tokens : constant Lexing.Token_Vectors.Vector := Lexing.Lex (Text);
   begin
      if Tokens.Length < 3 then
         return False;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 2 loop
         if Lexing.Image (Tokens (Index)) = "with"
           and then Tokens (Index + 1).Kind = Lexing.String_Literal
           and then Ada.Strings.Unbounded.To_String
             (Tokens (Index + 1).Text) = Project_Path
           and then Lexing.Image (Tokens (Index + 2)) = ";"
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_With;

   function Attribute_Strings
     (Text : String; Attribute_Name : String)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is
      Tokens : constant Lexing.Token_Vectors.Vector := Lexing.Lex (Text);
      Result : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Target : constant String := Text_Case.Lower (Attribute_Name);
   begin
      if Tokens.Length < 5 then
         return Result;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 4 loop
         if Lexing.Image (Tokens (Index)) = "for"
           and then Tokens (Index + 1).Kind = Lexing.Identifier
           and then Lexing.Image (Tokens (Index + 1)) = Target
           and then Lexing.Image (Tokens (Index + 2)) = "use"
           and then Lexing.Image (Tokens (Index + 3)) = "("
         then
            declare
               Depth : Natural := 1;
               Cursor : Positive := Index + 4;
            begin
               while Cursor <= Tokens.Last_Index and then Depth > 0 loop
                  if Lexing.Image (Tokens (Cursor)) = "(" then
                     Depth := Depth + 1;
                  elsif Lexing.Image (Tokens (Cursor)) = ")" then
                     Depth := Depth - 1;
                  elsif Depth = 1
                    and then Tokens (Cursor).Kind = Lexing.String_Literal
                  then
                     Result.Append (Tokens (Cursor).Text);
                  end if;
                  Cursor := Cursor + 1;
               end loop;
               if Depth = 0
                 and then Cursor <= Tokens.Last_Index
                 and then Lexing.Image (Tokens (Cursor)) = ";"
               then
                  return Result;
               end if;
               Result.Clear;
            end;
         end if;
      end loop;
      return Result;
   end Attribute_Strings;
end Giflib_Tooling.GPR_Analysis;
