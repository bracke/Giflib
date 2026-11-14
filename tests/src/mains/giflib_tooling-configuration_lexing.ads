with Giflib_Tooling.Configuration_Limits;

private package Giflib_Tooling.Configuration_Lexing is
   Maximum_Delimiter_Depth : constant :=
     Giflib_Tooling.Configuration_Limits.Maximum_Delimiter_Depth;
   type Quote_State is private;
   type Delimiter_State is private;
   type Quote_Event is (Text, Multiline_Opened, Multiline_Closed);

   function Outside (State : Quote_State) return Boolean;
   function In_Multiline (State : Quote_State) return Boolean;
   function At_Line_Continuation
     (Value : String; Position : Integer; State : Quote_State)
      return Boolean;

   procedure Advance
     (Value : String;
      Position : in out Integer;
      State : in out Quote_State;
      Event : out Quote_Event;
      Extra_Quotes : out Natural);
   procedure Consume_Line_Continuation
     (Value : String; Position : in out Integer; State : in out Quote_State);
   procedure End_Line (State : in out Quote_State);

   procedure Reset (State : out Delimiter_State);
   procedure Advance_Delimiter
     (State : in out Delimiter_State; Item : Character);
   function At_Top_Level (State : Delimiter_State) return Boolean;
private
   type Quote_Mode is
     (Outside_Quotes, Basic_String, Literal_String,
      Multiline_Basic_String, Multiline_Literal_String);
   type Quote_State is record
      Mode : Quote_Mode := Outside_Quotes;
      Escaped : Boolean := False;
   end record;
   type Delimiter_Stack is
     array (Positive range 1 .. Maximum_Delimiter_Depth) of Character;
   type Delimiter_State is record
      Stack : Delimiter_Stack := [others => ASCII.NUL];
      Depth : Natural range 0 .. Maximum_Delimiter_Depth := 0;
      Valid : Boolean := True;
   end record;
end Giflib_Tooling.Configuration_Lexing;
