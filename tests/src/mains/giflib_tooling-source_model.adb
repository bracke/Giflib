with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Strings;
with Ada.Strings.Fixed;

with Project_Tools.Ada_Source;

package body Giflib_Tooling.Source_Model is
   use type Ada.Containers.Count_Type;
   function Lower (Value : String) return String is
      Result : String := Value;
   begin
      for Ch of Result loop
         Ch := Ada.Characters.Handling.To_Lower (Ch);
      end loop;
      return Result;
   end Lower;

   function Image (Item : Token) return String is (To_String (Item.Text));

   function Image (Items : Token_Vectors.Vector) return String is
      Result : Unbounded_String;
   begin
      for Item of Items loop
         if Length (Result) > 0 then
            Append (Result, ' ');
         end if;
         Append (Result, Image (Item));
      end loop;
      return To_String (Result);
   end Image;

   function Is_Identifier_Character (Ch : Character) return Boolean is
     (Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

   function Lex (Text : String) return Token_Vectors.Vector is
      Result : Token_Vectors.Vector;
      Index : Integer := Text'First;

      procedure Add (Kind : Token_Kind; Value : String) is
      begin
         Result.Append
           (Token'(Kind => Kind, Text => To_Unbounded_String (Value)));
      end Add;
   begin
      while Index <= Text'Last loop
         if Text (Index) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Index := Index + 1;
         elsif Text (Index) = '-'
           and then Index < Text'Last and then Text (Index + 1) = '-'
         then
            Index := Index + 2;
            while Index <= Text'Last and then Text (Index) /= ASCII.LF loop
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '"' then
            declare
               Value : Unbounded_String;
            begin
               Index := Index + 1;
               while Index <= Text'Last loop
                  if Text (Index) = '"' then
                     if Index < Text'Last and then Text (Index + 1) = '"' then
                        Append (Value, '"');
                        Index := Index + 2;
                     else
                        Index := Index + 1;
                        exit;
                     end if;
                  else
                     Append (Value, Text (Index));
                     Index := Index + 1;
                  end if;
               end loop;
               Add (String_Literal, To_String (Value));
            end;
         elsif Text (Index) = '''
           and then Index + 2 <= Text'Last
           and then Text (Index + 2) = '''
         then
            Add (Character_Literal, Text (Index .. Index + 2));
            Index := Index + 3;
         elsif Is_Identifier_Character (Text (Index)) then
            declare
               First : constant Positive := Index;
            begin
               while Index <= Text'Last
                 and then Is_Identifier_Character (Text (Index))
               loop
                  Index := Index + 1;
               end loop;
               Add (Identifier, Lower (Text (First .. Index - 1)));
            end;
         elsif Index < Text'Last
           and then Text (Index .. Index + 1) in ":=" | "=>" | ".." | "<>"
         then
            Add (Symbol, Text (Index .. Index + 1));
            Index := Index + 2;
         else
            Add (Symbol, Text (Index .. Index));
            Index := Index + 1;
         end if;
      end loop;
      return Result;
   end Lex;

   function Contains_Tokens
     (Tokens : Token_Vectors.Vector;
      Pattern : Token_Vectors.Vector) return Boolean
   is
   begin
      if Pattern.Is_Empty or else Tokens.Length < Pattern.Length then
         return False;
      end if;
      for First in Tokens.First_Index .. Tokens.Last_Index loop
         exit when Natural (Tokens.Last_Index - First + 1) < Natural (Pattern.Length);
         declare
            Match : Boolean := True;
         begin
            for Offset in 0 .. Natural (Pattern.Length) - 1 loop
               if Tokens (First + Offset).Kind /= Pattern (Pattern.First_Index + Offset).Kind
                 or else Image (Tokens (First + Offset)) /=
                   Image (Pattern (Pattern.First_Index + Offset))
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
     (Contains_Tokens (Lex (Text), Lex (Pattern)));

   function Has_GPR_With (Text : String; Project_Path : String) return Boolean is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
   begin
      if Tokens.Length < 3 then
         return False;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 2 loop
         if Image (Tokens (Index)) = "with"
           and then Tokens (Index + 1).Kind = String_Literal
           and then Image (Tokens (Index + 1)) = Project_Path
           and then Image (Tokens (Index + 2)) = ";"
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_GPR_With;

   function GPR_Attribute_Strings
     (Text : String; Attribute_Name : String) return Name_Vectors.Vector
   is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
      Result : Name_Vectors.Vector;
      Target : constant String := Lower (Attribute_Name);
   begin
      if Tokens.Length < 5 then
         return Result;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 4 loop
         if Image (Tokens (Index)) = "for"
           and then Tokens (Index + 1).Kind = Identifier
           and then Image (Tokens (Index + 1)) = Target
           and then Image (Tokens (Index + 2)) = "use"
           and then Image (Tokens (Index + 3)) = "("
         then
            declare
               Depth : Natural := 1;
               Cursor : Positive := Index + 4;
            begin
               while Cursor <= Tokens.Last_Index and then Depth > 0 loop
                  if Image (Tokens (Cursor)) = "(" then
                     Depth := Depth + 1;
                  elsif Image (Tokens (Cursor)) = ")" then
                     Depth := Depth - 1;
                  elsif Depth = 1
                    and then Tokens (Cursor).Kind = String_Literal
                  then
                     Result.Append (Tokens (Cursor).Text);
                  end if;
                  Cursor := Cursor + 1;
               end loop;
               if Depth = 0
                 and then Cursor <= Tokens.Last_Index
                 and then Image (Tokens (Cursor)) = ";"
               then
                  return Result;
               end if;
               Result.Clear;
            end;
         end if;
      end loop;
      return Result;
   end GPR_Attribute_Strings;

   function Has_Config_Assignment
     (Text : String; Key : String; Value : String) return Boolean
   is
      use Ada.Strings;
      First : Integer := Text'First;
   begin
      while First <= Text'Last loop
         declare
            Last : Integer := First;
            In_String : Boolean := False;
            Comment : Integer := 0;
         begin
            while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
               if Text (Last) = '"' then
                  In_String := not In_String;
               elsif Text (Last) = '#' and then not In_String then
                  Comment := Last;
                  exit;
               end if;
               Last := Last + 1;
            end loop;
            if Comment > 0 then
               while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
                  Last := Last + 1;
               end loop;
            end if;
            declare
               Effective_Last : constant Integer :=
                 (if Comment > 0 then Comment - 1 else Last - 1);
               Line : constant String :=
                 (if Effective_Last < First then ""
                  else Ada.Strings.Fixed.Trim
                    (Text (First .. Effective_Last), Both));
               Equal : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
            begin
               if Equal > 0
                 and then Ada.Strings.Fixed.Trim
                   (Line (Line'First .. Equal - 1), Both) = Key
                 and then Ada.Strings.Fixed.Trim
                   (Line (Equal + 1 .. Line'Last), Both) = Value
               then
                  return True;
               end if;
            end;
            First := Last + 1;
         end;
      end loop;
      return False;
   end Has_Config_Assignment;

   function Record_Fields
     (Text : String; Type_Name : String) return Name_Vectors.Vector
   is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
      Result : Name_Vectors.Vector;
      Target : constant String := Lower (Type_Name);
      Index : Positive := (if Tokens.Is_Empty then 1 else Tokens.First_Index);
      Depth : Natural := 0;
      Declaration_First : Positive := 1;
      Found : Boolean := False;
   begin
      if Tokens.Is_Empty then
         return Result;
      end if;
      while Index <= Tokens.Last_Index loop
         if not Found
           and then Index < Tokens.Last_Index
           and then Image (Tokens (Index)) = "type"
           and then Image (Tokens (Index + 1)) = Target
         then
            while Index <= Tokens.Last_Index
              and then Image (Tokens (Index)) not in "record" | ";"
            loop
               Index := Index + 1;
            end loop;
            if Index <= Tokens.Last_Index
              and then Image (Tokens (Index)) = "record"
            then
               Found := True;
               Depth := 1;
               Declaration_First := Index + 1;
            end if;
         elsif Found
           and then Image (Tokens (Index)) = "end"
           and then Index < Tokens.Last_Index
           and then Image (Tokens (Index + 1)) = "record"
         then
            Depth := Depth - 1;
            exit when Depth = 0;
            Index := Index + 1;
         elsif Found and then Image (Tokens (Index)) = "record" then
            Depth := Depth + 1;
         elsif Found and then Depth = 1 and then Image (Tokens (Index)) = ";" then
            declare
               Colon : Natural := 0;
            begin
               for Cursor in Declaration_First .. Index - 1 loop
                  if Image (Tokens (Cursor)) = ":" then
                     Colon := Cursor;
                     exit;
                  end if;
               end loop;
               if Colon > Declaration_First then
                  for Cursor in Declaration_First .. Colon - 1 loop
                     if Tokens (Cursor).Kind = Identifier then
                        Result.Append (Tokens (Cursor).Text);
                     end if;
                  end loop;
               end if;
            end;
            Declaration_First := Index + 1;
         end if;
         Index := Index + 1;
      end loop;
      return Result;
   end Record_Fields;

   function Session_Identifiers
     (Text : String; Type_Name : String) return Name_Vectors.Vector
   is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
      Result : Name_Vectors.Vector;
      Target : constant String := Lower (Type_Name);
   begin
      if Tokens.Length < 3 then
         return Result;
      end if;
      for Colon in Tokens.First_Index + 1 .. Tokens.Last_Index - 1 loop
         if Image (Tokens (Colon)) = ":"
           and then Tokens (Colon - 1).Kind = Identifier
         then
            for Cursor in Colon + 1 .. Tokens.Last_Index loop
               exit when Image (Tokens (Cursor)) in ";" | ")" | ":=";
               if Tokens (Cursor).Kind = Identifier
                 and then Image (Tokens (Cursor)) = Target
               then
                  declare
                     Candidate : Positive := Colon - 1;
                  begin
                     loop
                        if not Contains
                          (Result, Image (Tokens (Candidate)))
                        then
                           Result.Append (Tokens (Candidate).Text);
                        end if;
                        exit when Candidate < Tokens.First_Index + 2
                          or else Image (Tokens (Candidate - 1)) /= ",";
                        Candidate := Candidate - 2;
                        exit when Tokens (Candidate).Kind /= Identifier;
                     end loop;
                  end;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
      return Result;
   end Session_Identifiers;

   function Nested_Program_Units (Text : String) return Name_Vectors.Vector is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
      Active_Subprograms : Name_Vectors.Vector;
      Result : Name_Vectors.Vector;

      procedure Include (Name : Unbounded_String) is
      begin
         Result.Append (Name);
      end Include;
   begin
      if Tokens.Length < 3 then
         return Result;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 2 loop
         if Image (Tokens (Index)) in "procedure" | "function"
           and then Tokens (Index + 1).Kind = Identifier
         then
            declare
               Parentheses : Natural := 0;
               Is_Body : Boolean := False;
            begin
               for Cursor in Index + 2 .. Tokens.Last_Index loop
                  if Image (Tokens (Cursor)) = "(" then
                     Parentheses := Parentheses + 1;
                  elsif Image (Tokens (Cursor)) = ")" and then Parentheses > 0 then
                     Parentheses := Parentheses - 1;
                  elsif Parentheses = 0 and then Image (Tokens (Cursor)) = ";" then
                     exit;
                  elsif Parentheses = 0 and then Image (Tokens (Cursor)) = "is" then
                     Is_Body :=
                       Cursor = Tokens.Last_Index
                       or else Image (Tokens (Cursor + 1)) not in
                         "separate" | "new" | "abstract" | "(";
                     exit;
                  end if;
               end loop;
               if not Active_Subprograms.Is_Empty then
                  Include (Tokens (Index + 1).Text);
               end if;
               if Is_Body then
                  Active_Subprograms.Append (Tokens (Index + 1).Text);
               end if;
            end;
         elsif not Active_Subprograms.Is_Empty
           and then Image (Tokens (Index)) = "package"
           and then Tokens (Index + 1).Kind = Identifier
         then
            Include (Tokens (Index + 1).Text);
         elsif not Active_Subprograms.Is_Empty
           and then Image (Tokens (Index)) = "end"
           and then Image (Tokens (Index + 1)) =
             To_String (Active_Subprograms.Last_Element)
           and then Image (Tokens (Index + 2)) = ";"
         then
            Active_Subprograms.Delete_Last;
         end if;
      end loop;
      return Result;
   end Nested_Program_Units;

   function Has_Nested_Program_Unit (Text : String) return Boolean is
     (not Nested_Program_Units (Text).Is_Empty);

   procedure Scan_Statements
     (Text : String;
      Process : not null access procedure (Statement : Token_Vectors.Vector))
   is
      Tokens : constant Token_Vectors.Vector := Lex (Text);
      Statement : Token_Vectors.Vector;
   begin
      for Item of Tokens loop
         if Image (Item) = ";" then
            if not Statement.Is_Empty then
               Process (Statement);
               Statement.Clear;
            end if;
         else
            Statement.Append (Item);
         end if;
      end loop;
      if not Statement.Is_Empty then
         Process (Statement);
      end if;
   end Scan_Statements;

   function Contains (Names : Name_Vectors.Vector; Name : String) return Boolean is
      Target : constant String := Lower (Name);
   begin
      for Item of Names loop
         if To_String (Item) = Target then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Join_Callee
     (Statement : Token_Vectors.Vector; Open_Paren : Positive) return String
   is
      Result : Unbounded_String;
      First : Positive := Open_Paren;
   begin
      if Open_Paren = Statement.First_Index then
         return "";
      end if;
      First := Open_Paren - 1;
      if Statement (First).Kind /= Identifier then
         return "";
      end if;
      if Project_Tools.Ada_Source.Is_Ada_Reserved_Word
        (Image (Statement (First)))
      then
         return "";
      end if;
      while First >= Statement.First_Index + 2
        and then Image (Statement (First - 1)) = "."
        and then Statement (First - 2).Kind = Identifier
      loop
         First := First - 2;
      end loop;
      for Index in First .. Open_Paren - 1 loop
         if Statement (Index).Kind /= Identifier
           and then Image (Statement (Index)) /= "."
         then
            return "";
         end if;
         Append (Result, Image (Statement (Index)));
      end loop;
      return To_String (Result);
   end Join_Callee;

   function Enclosing_Callee
     (Statement : Token_Vectors.Vector; Actual : Positive) return String
   is
      Depth : Natural := 0;
   begin
      if Actual = Statement.First_Index then
         return "";
      end if;
      for Index in reverse Statement.First_Index .. Actual - 1 loop
         if Image (Statement (Index)) = ")" then
            Depth := Depth + 1;
         elsif Image (Statement (Index)) = "(" then
            if Depth = 0 then
               declare
                  Callee : constant String := Join_Callee (Statement, Index);
               begin
                  if Callee /= "" then
                     return Callee;
                  end if;
               end;
            end if;
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
         end if;
      end loop;
      return "";
   end Enclosing_Callee;
end Giflib_Tooling.Source_Model;
