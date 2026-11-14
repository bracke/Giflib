with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Lexing;

package body Giflib_Tooling.Configuration_Normalization is
   package Lexing renames Giflib_Tooling.Configuration_Lexing;

   function Normalize (Value : String) return String is
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Quotes : Lexing.Quote_State;
      Index : Integer := Value'First;
   begin
      while Index <= Value'Last loop
         if Lexing.At_Line_Continuation (Value, Index, Quotes) then
            Lexing.Consume_Line_Continuation (Value, Index, Quotes);
         else
            declare
               Start : constant Integer := Index;
               Was_Outside : constant Boolean := Lexing.Outside (Quotes);
               Event : Lexing.Quote_Event;
               Extra_Quotes : Natural;
            begin
               Lexing.Advance
                 (Value, Index, Quotes, Event, Extra_Quotes);
               case Event is
                  when Lexing.Multiline_Opened =>
                     Ada.Strings.Unbounded.Append (Result, Value (Start));
                     if Index <= Value'Last
                       and then Value (Index) = ASCII.CR
                     then
                        Index := Index + 1;
                     end if;
                     if Index <= Value'Last
                       and then Value (Index) = ASCII.LF
                     then
                        Index := Index + 1;
                     end if;
                  when Lexing.Multiline_Closed =>
                     for Count in 1 .. Extra_Quotes + 1 loop
                        pragma Unreferenced (Count);
                        Ada.Strings.Unbounded.Append (Result, Value (Start));
                     end loop;
                  when Lexing.Text =>
                     if not
                       (Was_Outside
                        and then Index = Start + 1
                        and then Value (Start) in
                          ' ' | ASCII.HT | ASCII.CR)
                     then
                        Ada.Strings.Unbounded.Append
                          (Result, Value (Start .. Index - 1));
                     end if;
               end case;
            end;
         end if;
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Normalize;
end Giflib_Tooling.Configuration_Normalization;
