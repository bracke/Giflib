with Giflib_Tooling.Configuration_Quotes;

package body Giflib_Tooling.Configuration_Lexing is
   package Quotes renames Giflib_Tooling.Configuration_Quotes;

   function Outside (State : Quote_State) return Boolean is
     (State.Mode = Outside_Quotes);

   function In_Multiline (State : Quote_State) return Boolean is
     (State.Mode in Multiline_Basic_String | Multiline_Literal_String);

   function Delimiter (State : Quote_State) return Character is
     (if State.Mode in Basic_String | Multiline_Basic_String
      then '"' else ''');

   function At_Line_Continuation
     (Value : String; Position : Integer; State : Quote_State)
      return Boolean is
     (State.Mode = Multiline_Basic_String
      and then not State.Escaped
      and then Position >= Value'First
      and then Position <= Value'Last
      and then Value (Position) = '\'
      and then
        ((Position < Value'Last and then Value (Position + 1) = ASCII.LF)
         or else
           (Position <= Value'Last - 2
            and then Value (Position + 1) = ASCII.CR
            and then Value (Position + 2) = ASCII.LF)));

   procedure Advance
     (Value : String;
      Position : in out Integer;
      State : in out Quote_State;
      Event : out Quote_Event;
      Extra_Quotes : out Natural)
   is
      Character : constant Standard.Character := Value (Position);
   begin
      Event := Text;
      Extra_Quotes := 0;
      if State.Mode = Outside_Quotes
        and then Character in '"' | '''
        and then Quotes.Triple_At (Value, Position, Character)
      then
         State.Mode :=
           (if Character = '"'
            then Multiline_Basic_String else Multiline_Literal_String);
         State.Escaped := False;
         Position := Position + 3;
         Event := Multiline_Opened;
      elsif State.Mode = Outside_Quotes and then Character in '"' | ''' then
         State.Mode :=
           (if Character = '"' then Basic_String else Literal_String);
         State.Escaped := False;
         Position := Position + 1;
      elsif In_Multiline (State)
        and then Character = Delimiter (State)
        and then not State.Escaped
      then
         declare
            Count : constant Natural :=
              Quotes.Run_Length (Value, Position, Character);
         begin
            Position := Position + Integer (Count);
            if Count in 3 .. 5 then
               Extra_Quotes := Count - 3;
               State.Mode := Outside_Quotes;
               State.Escaped := False;
               Event := Multiline_Closed;
            end if;
         end;
      elsif State.Mode in Basic_String | Multiline_Basic_String
        and then Character = '\'
        and then not State.Escaped
      then
         State.Escaped := True;
         Position := Position + 1;
      elsif State.Mode in Basic_String | Literal_String
        and then Character = Delimiter (State)
        and then not State.Escaped
      then
         State.Mode := Outside_Quotes;
         Position := Position + 1;
      else
         State.Escaped := False;
         Position := Position + 1;
      end if;
   end Advance;

   procedure Consume_Line_Continuation
     (Value : String; Position : in out Integer; State : in out Quote_State) is
   begin
      Position := Position + 1;
      if Value (Position) = ASCII.CR then
         Position := Position + 1;
      end if;
      Position := Position + 1;
      while Position <= Value'Last
        and then Value (Position) in ' ' | ASCII.HT | ASCII.CR | ASCII.LF
      loop
         Position := Position + 1;
      end loop;
      State.Escaped := False;
   end Consume_Line_Continuation;

   procedure End_Line (State : in out Quote_State) is
   begin
      State.Escaped := False;
      if not In_Multiline (State) then
         State.Mode := Outside_Quotes;
      end if;
   end End_Line;

   procedure Reset (State : out Delimiter_State) is
   begin
      State :=
        (Stack => [others => ASCII.NUL], Depth => 0, Valid => True);
   end Reset;

   procedure Advance_Delimiter
     (State : in out Delimiter_State; Item : Character) is
      Expected : Character;
   begin
      if not State.Valid then
         return;
      elsif Item in '[' | '{' then
         if State.Depth = Maximum_Delimiter_Depth then
            State.Valid := False;
         else
            State.Depth := State.Depth + 1;
            State.Stack (State.Depth) := Item;
         end if;
         return;
      elsif Item not in ']' | '}' then
         return;
      end if;
      Expected := (if Item = ']' then '[' else '{');
      if State.Depth = 0
        or else State.Stack (State.Depth) /= Expected
      then
         State.Valid := False;
      else
         State.Stack (State.Depth) := ASCII.NUL;
         State.Depth := State.Depth - 1;
      end if;
   end Advance_Delimiter;

   function At_Top_Level (State : Delimiter_State) return Boolean is
     (State.Valid and then State.Depth = 0);
end Giflib_Tooling.Configuration_Lexing;
