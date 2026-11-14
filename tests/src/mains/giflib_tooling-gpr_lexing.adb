with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.GPR_Lexing is
   use Ada.Strings.Unbounded;
   package Limits renames Giflib_Tooling.Source_Limits;
   package Text_Case renames Giflib_Tooling.Text_Case;

   function Is_Identifier_Start (Value : Character) return Boolean is
     (Value in 'a' .. 'z' | 'A' .. 'Z');

   function Is_Identifier_Character (Value : Character) return Boolean is
     (Is_Identifier_Start (Value) or else Value in '0' .. '9' | '_');

   function Lex (Text : String) return Token_Vectors.Vector is
      Result : Token_Vectors.Vector;
      Cursor : Integer := Text'First;

      procedure Append (Kind : Token_Kind; Value : String) is
      begin
         if Natural (Result.Length) >=
           Limits.Default_Analysis_Limits.Parsing.Maximum_Tokens
         then
            raise Input_Error with "GPR token limit exceeded";
         end if;
         Result.Append (Token'(Kind, To_Unbounded_String (Value)));
      end Append;
   begin
      if Text'Length >
        Limits.Default_Analysis_Limits.Parsing.Maximum_Source_Length
      then
         raise Input_Error with "GPR source length limit exceeded";
      end if;
      while Cursor <= Text'Last loop
         if Text (Cursor) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Cursor := Cursor + 1;
         elsif Text (Cursor) = '-'
           and then Cursor < Text'Last
           and then Text (Cursor + 1) = '-'
         then
            Cursor := Cursor + 2;
            while Cursor <= Text'Last and then Text (Cursor) /= ASCII.LF loop
               Cursor := Cursor + 1;
            end loop;
         elsif Text (Cursor) = '"' then
            declare
               Value : Unbounded_String;
               Closed : Boolean := False;
            begin
               Cursor := Cursor + 1;
               while Cursor <= Text'Last loop
                  if Text (Cursor) = '"' then
                     if Cursor < Text'Last and then Text (Cursor + 1) = '"' then
                        Ada.Strings.Unbounded.Append (Value, '"');
                        Cursor := Cursor + 2;
                     else
                        Cursor := Cursor + 1;
                        Closed := True;
                        exit;
                     end if;
                  else
                     Ada.Strings.Unbounded.Append (Value, Text (Cursor));
                     Cursor := Cursor + 1;
                  end if;
               end loop;
               if not Closed then
                  raise Input_Error with "unterminated GPR string literal";
               end if;
               Append (String_Literal, To_String (Value));
            end;
         elsif Is_Identifier_Start (Text (Cursor)) then
            declare
               First : constant Integer := Cursor;
            begin
               while Cursor <= Text'Last
                 and then Is_Identifier_Character (Text (Cursor))
               loop
                  Cursor := Cursor + 1;
               end loop;
               Append
                 (Identifier, Text_Case.Lower (Text (First .. Cursor - 1)));
            end;
         else
            Append (Symbol, Text (Cursor .. Cursor));
            Cursor := Cursor + 1;
         end if;
      end loop;
      return Result;
   end Lex;

   function Image (Item : Token) return String is
     (To_String (Item.Text));
end Giflib_Tooling.GPR_Lexing;
