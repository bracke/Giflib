package body Giflib_Tooling.Configuration_Quotes is
   function Run_Length
     (Value : String; Position : Integer; Delimiter : Character)
      return Natural
   is
      Cursor : Integer := Position;
      Result : Natural := 0;
   begin
      if Position < Value'First or else Position > Value'Last then
         return 0;
      end if;
      while Value (Cursor) = Delimiter loop
         Result := Result + 1;
         exit when Cursor = Value'Last;
         Cursor := Cursor + 1;
      end loop;
      return Result;
   end Run_Length;

   function Triple_At
     (Value : String; Position : Integer; Delimiter : Character)
      return Boolean is
     (Position >= Value'First
      and then Position <= Value'Last
      and then Value'Last - Position >= 2
      and then Value (Position) = Delimiter
      and then Value (Position + 1) = Delimiter
      and then Value (Position + 2) = Delimiter);

   function Triple_At (Value : String; Position : Integer) return Boolean is
     (Position >= Value'First
      and then Position <= Value'Last
      and then Value (Position) in '"' | '''
      and then Triple_At (Value, Position, Value (Position)));
end Giflib_Tooling.Configuration_Quotes;
