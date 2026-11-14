with Ada.Strings.Fixed;

with Giflib_Tooling.Configuration_Lexing;
with Giflib_Tooling.Configuration_Text;

package body Giflib_Tooling.Configuration_Values is
   package Lexing renames Giflib_Tooling.Configuration_Lexing;
   package Text renames Giflib_Tooling.Configuration_Text;
   use type Lexing.Quote_Event;

   function String_Value_Matches
     (Value : String; Expected : String) return Boolean
   is
      Item : constant String := Text.Trim (Value);
   begin
      return Item'Length >= 2
        and then Item (Item'First) in '"' | '''
        and then Item (Item'Last) = Item (Item'First)
        and then Item (Item'First + 1 .. Item'Last - 1) = Expected;
   end String_Value_Matches;

   function Inline_String_Value_Matches
     (Value : String; Key : String; Expected : String) return Boolean
   is
      Item : constant String := Text.Trim (Value);
      Cursor : Integer;
      Field_First : Integer;
      Quotes : Lexing.Quote_State;
      Delimiters : Lexing.Delimiter_State;

      function Field_Matches (Field : String) return Boolean is
         Equal : constant Natural := Ada.Strings.Fixed.Index (Field, "=");
      begin
         return Equal > 0
           and then Text.Trim (Field (Field'First .. Equal - 1)) = Key
           and then String_Value_Matches
             (Field (Equal + 1 .. Field'Last), Expected);
      end Field_Matches;
   begin
      if Item'Length < 2
        or else Item (Item'First) /= '{'
        or else Item (Item'Last) /= '}'
      then
         return False;
      end if;
      Cursor := Item'First + 1;
      Field_First := Cursor;
      while Cursor <= Item'Last - 1 loop
         declare
            Start : constant Integer := Cursor;
            Was_Outside : constant Boolean := Lexing.Outside (Quotes);
            Event : Lexing.Quote_Event;
            Extra : Natural;
         begin
            Lexing.Advance (Item, Cursor, Quotes, Event, Extra);
            pragma Unreferenced (Extra);
            if Was_Outside and then Event = Lexing.Text then
               if Item (Start) = ','
                 and then Lexing.At_Top_Level (Delimiters)
               then
                  if Field_Matches
                    (Text.Trim (Item (Field_First .. Start - 1)))
                  then
                     return True;
                  end if;
                  Field_First := Cursor;
               elsif Item (Start) in '[' | '{' | ']' | '}' then
                  Lexing.Advance_Delimiter (Delimiters, Item (Start));
               end if;
            end if;
         end;
      end loop;
      return Lexing.At_Top_Level (Delimiters)
        and then Field_Matches
          (Text.Trim (Item (Field_First .. Item'Last - 1)));
   end Inline_String_Value_Matches;
end Giflib_Tooling.Configuration_Values;
