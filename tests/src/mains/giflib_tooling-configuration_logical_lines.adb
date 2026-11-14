with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Lexing;
with Giflib_Tooling.Configuration_Text;

package body Giflib_Tooling.Configuration_Logical_Lines is
   package Lexing renames Giflib_Tooling.Configuration_Lexing;
   package Text_Values renames Giflib_Tooling.Configuration_Text;

   procedure Scan
     (Text : String;
      Process : not null access procedure
        (Line : String; Stop : in out Boolean);
      Incomplete : out Boolean)
   is
      First : Integer := Text'First;
      Stop : Boolean := False;
      Quotes : Lexing.Quote_State;
      Logical_Line : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Incomplete := False;
      while First <= Text'Last and then not Stop loop
         declare
            Last : Integer := First;
            Comment : Integer := 0;
         begin
            while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
               if Text (Last) = '#' and then Lexing.Outside (Quotes) then
                  Comment := Last;
                  exit;
               else
                  declare
                     Event : Lexing.Quote_Event;
                     Extra : Natural;
                  begin
                     Lexing.Advance (Text, Last, Quotes, Event, Extra);
                     pragma Unreferenced (Event, Extra);
                  end;
               end if;
            end loop;
            if Comment > 0 then
               while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
                  Last := Last + 1;
               end loop;
            end if;
            Lexing.End_Line (Quotes);
            declare
               Effective_Last : constant Integer :=
                 (if Comment > 0 then Comment - 1 else Last - 1);
            begin
               if Ada.Strings.Unbounded.Length (Logical_Line) > 0 then
                  Ada.Strings.Unbounded.Append (Logical_Line, ASCII.LF);
               end if;
               if Effective_Last >= First then
                  Ada.Strings.Unbounded.Append
                    (Logical_Line, Text (First .. Effective_Last));
               end if;
               if not Lexing.In_Multiline (Quotes) then
                  Process
                    (Text_Values.Trim
                       (Ada.Strings.Unbounded.To_String (Logical_Line)),
                     Stop);
                  Logical_Line := Ada.Strings.Unbounded.Null_Unbounded_String;
               end if;
            end;
            First := Last + 1;
         end;
      end loop;
      Incomplete := not Stop
        and then
          (Lexing.In_Multiline (Quotes)
           or else Ada.Strings.Unbounded.Length (Logical_Line) > 0);
   end Scan;
end Giflib_Tooling.Configuration_Logical_Lines;
