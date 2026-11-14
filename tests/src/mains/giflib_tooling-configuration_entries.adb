with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Entry_Parsing;
with Giflib_Tooling.Configuration_Lexing;
with Giflib_Tooling.Configuration_Logical_Lines;

package body Giflib_Tooling.Configuration_Entries is
   package Lexing renames Giflib_Tooling.Configuration_Lexing;
   package Lines renames Giflib_Tooling.Configuration_Logical_Lines;
   package Parsing renames Giflib_Tooling.Configuration_Entry_Parsing;
   use type Lexing.Quote_Event;

   procedure Update_Nesting
     (Value : String; Delimiters : in out Lexing.Delimiter_State)
   is
      Quotes : Lexing.Quote_State;
      Index : Integer := Value'First;
   begin
      while Index <= Value'Last loop
         declare
            Start : constant Integer := Index;
            Was_Outside : constant Boolean := Lexing.Outside (Quotes);
            Event : Lexing.Quote_Event;
            Extra : Natural;
         begin
            Lexing.Advance (Value, Index, Quotes, Event, Extra);
            pragma Unreferenced (Extra);
            if Was_Outside and then Event = Lexing.Text
              and then Value (Start) in '[' | '{' | ']' | '}'
            then
               Lexing.Advance_Delimiter (Delimiters, Value (Start));
            end if;
         end;
      end loop;
   end Update_Nesting;

   procedure Scan
     (Text : String;
      Process : not null access procedure
        (Item : Parsed_Entry; Stop : in out Boolean))
   is
      Pending : Ada.Strings.Unbounded.Unbounded_String;
      Delimiters : Lexing.Delimiter_State;
      Stopped : Boolean := False;
      Incomplete_Line : Boolean;

      procedure Emit (Line : String; Stop : in out Boolean) is
      begin
         Process (Parsing.Parse (Line), Stop);
      end Emit;

      procedure Inspect (Line : String; Stop : in out Boolean) is
         Equal : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Ada.Strings.Unbounded.Length (Pending) = 0 then
            if Equal = 0 then
               Emit (Line, Stop);
            else
               Ada.Strings.Unbounded.Append (Pending, Line);
               Lexing.Reset (Delimiters);
               Update_Nesting (Line (Equal + 1 .. Line'Last), Delimiters);
               if Lexing.At_Top_Level (Delimiters) then
                  Emit (Ada.Strings.Unbounded.To_String (Pending), Stop);
                  Pending := Ada.Strings.Unbounded.Null_Unbounded_String;
               end if;
            end if;
         else
            if Line /= "" then
               Ada.Strings.Unbounded.Append (Pending, " ");
               Ada.Strings.Unbounded.Append (Pending, Line);
               Update_Nesting (Line, Delimiters);
            end if;
            if Lexing.At_Top_Level (Delimiters) then
               Emit (Ada.Strings.Unbounded.To_String (Pending), Stop);
               Pending := Ada.Strings.Unbounded.Null_Unbounded_String;
            end if;
         end if;
         Stopped := Stop;
      end Inspect;
   begin
      Lines.Scan (Text, Inspect'Access, Incomplete_Line);
      if not Stopped
        and then (Incomplete_Line
                  or else Ada.Strings.Unbounded.Length (Pending) > 0)
      then
         declare
            Stop : Boolean := False;
         begin
            Process ((Kind => Malformed_Assignment_Entry), Stop);
         end;
      end if;
   end Scan;

end Giflib_Tooling.Configuration_Entries;
