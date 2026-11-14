with Ada.Exceptions;
with Ada.Strings.Unbounded;

with Project_Tools.Ada_Source;

with Giflib_Tooling.Text_Case;
with Giflib_Tooling.Token_Values;
with Giflib_Tooling.Model_Storage;

package body Giflib_Tooling.Source_Lexing is
   use Ada.Strings.Unbounded;
   use Source;
   package Values renames Giflib_Tooling.Token_Values;
   package Text_Case renames Giflib_Tooling.Text_Case;
   subtype Parsing_Limits is Giflib_Tooling.Source_Limits.Parsing_Limits;
   package Storage_Budgets renames Giflib_Tooling.Model_Storage_Budgets;
   package Model_Storage renames Giflib_Tooling.Model_Storage;

   function Is_Identifier_Start (Ch : Character) return Boolean is
     (Ch in 'a' .. 'z' | 'A' .. 'Z');

   function Is_Identifier_Character (Ch : Character) return Boolean is
     (Is_Identifier_Start (Ch) or else Ch in '0' .. '9' | '_');

   function Lex_Rebased
     (Text : String;
      Position : Natural;
      Complete_Source : Boolean;
      Limits : Parsing_Limits;
      Storage : in out Storage_Budgets.Budget) return Token_Vectors.Vector
   is
      Result : Token_Vectors.Vector;
      Index : Integer := Text'First;

      procedure Add (Kind : Token_Kind; Value : String; Position : Positive) is
      begin
         if Natural (Result.Length) >= Limits.Maximum_Tokens then
            raise Input_Error with "source token limit exceeded";
         end if;
         Model_Storage.Charge_Token (Storage, Value'Length);
         declare
            Value_Text : constant Unbounded_String :=
              To_Unbounded_String (Value);
         begin
            case Kind is
               when Identifier =>
                  Result.Append
                    (Values.Create_Identifier (Value_Text, Position));
               when Reserved_Word =>
                  Result.Append
                    (Values.Create_Reserved_Word (Value_Text, Position));
               when Numeric_Literal =>
                  Result.Append (Values.Create_Numeric (Value_Text, Position));
               when String_Literal =>
                  Result.Append (Values.Create_String (Value_Text, Position));
               when Character_Literal =>
                  Result.Append
                    (Values.Create_Character (Value_Text, Position));
               when Symbol =>
                  Result.Append (Values.Create_Symbol (Value_Text, Position));
            end case;
         end;
      exception
         when E : Values.Invalid_Token =>
            raise Input_Error with Ada.Exceptions.Exception_Message (E);
      end Add;

      function Position_At (Source_Index : Integer) return Positive is
        (Positive (Source_Index - Text'First + 1));

      procedure Require_Consumed (Exclusive_Last : Integer) is
      begin
         if Exclusive_Last - Text'First >
           Limits.Maximum_Source_Length
         then
            raise Input_Error with "source length limit exceeded";
         end if;
      end Require_Consumed;
   begin
      if Complete_Source
        and then Text'Length > Limits.Maximum_Source_Length
      then
         raise Input_Error with "source length limit exceeded";
      end if;
      while Index <= Text'Last loop
         exit when not Complete_Source and then Position_At (Index) > Position;
         Require_Consumed (Index + 1);
         if Text (Index) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Index := Index + 1;
         elsif Text (Index) = '-'
           and then Index < Text'Last and then Text (Index + 1) = '-'
         then
            Index := Index + 2;
            while Index <= Text'Last and then Text (Index) /= ASCII.LF loop
               exit when not Complete_Source
                 and then Position_At (Index) > Position;
               Require_Consumed (Index + 1);
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '"' then
            declare
               Value : Unbounded_String;
               First : constant Integer := Index;
               Closed : Boolean := False;
            begin
               Index := Index + 1;
               while Index <= Text'Last loop
                  Require_Consumed (Index + 1);
                  if Text (Index) = '"' then
                     if Index < Text'Last and then Text (Index + 1) = '"' then
                        Require_Consumed (Index + 2);
                        Append (Value, '"');
                        Index := Index + 2;
                     else
                        Index := Index + 1;
                        Closed := True;
                        exit;
                     end if;
                  else
                     Append (Value, Text (Index));
                     Index := Index + 1;
                  end if;
               end loop;
               if not Closed then
                  raise Input_Error with "unterminated string literal";
               end if;
               Require_Consumed (Index);
               Add
                 (String_Literal, To_String (Value), Position_At (First));
            end;
         elsif Text (Index) = '''
           and then Index + 2 <= Text'Last
           and then Text (Index + 2) = '''
         then
            Require_Consumed (Index + 3);
            Add
              (Character_Literal, Text (Index .. Index + 2),
               Position_At (Index));
            Index := Index + 3;
         elsif Text (Index) in '0' .. '9' then
            declare
               First : constant Integer := Index;
            begin
               while Index <= Text'Last loop
                  Require_Consumed (Index + 1);
                  exit when not
                    (Is_Identifier_Character (Text (Index))
                     or else Text (Index) = '#'
                     or else
                       (Text (Index) = '.'
                        and then
                          (Index = Text'Last
                           or else Text (Index + 1) /= '.'))
                     or else
                       (Text (Index) in '+' | '-'
                        and then Index > First
                        and then Text (Index - 1) in 'e' | 'E'));
                  Index := Index + 1;
               end loop;
               Require_Consumed (Index);
               Add
                 (Numeric_Literal,
                  Text_Case.Lower (Text (First .. Index - 1)),
                  Position_At (First));
            end;
         elsif Is_Identifier_Start (Text (Index)) then
            declare
               First : constant Integer := Index;
            begin
               while Index <= Text'Last
                 and then Is_Identifier_Character (Text (Index))
               loop
                  Require_Consumed (Index + 1);
                  Index := Index + 1;
               end loop;
               Require_Consumed (Index);
               declare
                  Value : constant String :=
                    Text_Case.Lower (Text (First .. Index - 1));
                  Kind : constant Token_Kind :=
                    (if Project_Tools.Ada_Source.Is_Ada_Reserved_Word (Value)
                     then Reserved_Word else Identifier);
               begin
                  Add (Kind, Value, Position_At (First));
               end;
            end;
         elsif Index < Text'Last
           and then Text (Index .. Index + 1) in ":=" | "=>" | ".." | "<>"
         then
            Require_Consumed (Index + 2);
            Add
              (Symbol, Text (Index .. Index + 1), Position_At (Index));
            Index := Index + 2;
         else
            Require_Consumed (Index + 1);
            Add (Symbol, Text (Index .. Index), Position_At (Index));
            Index := Index + 1;
         end if;
      end loop;
      return Result;
   end Lex_Rebased;

   function Lex_Until
     (Text : String;
      Position : Natural;
      Complete_Source : Boolean;
      Limits : Parsing_Limits;
      Storage : in out Storage_Budgets.Budget) return Token_Vectors.Vector
   is
   begin
      if Text'Last <= Integer'Last - 3 then
         return Lex_Rebased (Text, Position, Complete_Source, Limits, Storage);
      end if;
      declare
         Rebased : constant String (1 .. Text'Length) := Text;
      begin
         return Lex_Rebased
           (Rebased, Position, Complete_Source, Limits, Storage);
      end;
   end Lex_Until;

   function Lex
     (Text : String;
      Limits : Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Token_Vectors.Vector
   is
      Storage : Storage_Budgets.Budget (Limits.Maximum_Model_Storage);
   begin
      return Lex_Until (Text, Natural'Last, True, Limits, Storage);
   end Lex;

   function Lex
     (Text : String;
      Limits : Parsing_Limits;
      Storage : in out Storage_Budgets.Budget)
      return Token_Vectors.Vector is
     (Lex_Until (Text, Natural'Last, True, Limits, Storage));

   function Lex_Through
     (Text : String;
      Position : Natural;
      Limits : Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Token_Vectors.Vector
   is
      Storage : Storage_Budgets.Budget (Limits.Maximum_Model_Storage);
   begin
      return Lex_Until (Text, Position, False, Limits, Storage);
   end Lex_Through;

   function Lex_Through
     (Text : String;
      Position : Natural;
      Limits : Parsing_Limits;
      Storage : in out Storage_Budgets.Budget)
      return Token_Vectors.Vector is
     (Lex_Until (Text, Position, False, Limits, Storage));
end Giflib_Tooling.Source_Lexing;
