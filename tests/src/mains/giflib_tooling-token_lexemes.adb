with Ada.Characters.Handling;

package body Giflib_Tooling.Token_Lexemes is
   function Is_Letter (Value : Character) return Boolean is
     (Value in 'a' .. 'z' | 'A' .. 'Z');

   function Digit_Value (Value : Character) return Natural is
      Lower : constant Character := Ada.Characters.Handling.To_Lower (Value);
   begin
      if Lower in '0' .. '9' then
         return Character'Pos (Lower) - Character'Pos ('0');
      elsif Lower in 'a' .. 'f' then
         return Character'Pos (Lower) - Character'Pos ('a') + 10;
      end if;
      return 16;
   end Digit_Value;

   function Valid_Sequence
     (Value : String; First, Last : Integer; Base : Positive) return Boolean
   is
      Expect_Digit : Boolean := True;
   begin
      if First > Last then
         return False;
      end if;
      for Index in First .. Last loop
         if Value (Index) = '_' then
            if Expect_Digit then
               return False;
            end if;
            Expect_Digit := True;
         elsif Digit_Value (Value (Index)) < Base then
            Expect_Digit := False;
         else
            return False;
         end if;
      end loop;
      return not Expect_Digit;
   end Valid_Sequence;

   function Valid_Identifier (Value : String) return Boolean is
      Previous_Underscore : Boolean := False;
   begin
      if Value'Length = 0 or else not Is_Letter (Value (Value'First)) then
         return False;
      end if;
      for Character of Value loop
         if Character = '_' then
            if Previous_Underscore then
               return False;
            end if;
            Previous_Underscore := True;
         elsif Is_Letter (Character) or else Character in '0' .. '9' then
            Previous_Underscore := False;
         else
            return False;
         end if;
      end loop;
      return not Previous_Underscore;
   end Valid_Identifier;

   function Exponent_Is_Valid
     (Value : String; Marker, Last : Integer) return Boolean
   is
      First : Integer := Marker + 1;
   begin
      if Marker > Last
        or else Value (Marker) not in 'e' | 'E'
      then
         return False;
      end if;
      if First <= Last and then Value (First) in '+' | '-' then
         First := First + 1;
      end if;
      return Valid_Sequence (Value, First, Last, 10);
   end Exponent_Is_Valid;

   function Base_Of
     (Value : String; First, Last : Integer) return Natural
   is
      Result : Natural := 0;
   begin
      if not Valid_Sequence (Value, First, Last, 10) then
         return 0;
      end if;
      for Index in First .. Last loop
         if Value (Index) /= '_' then
            declare
               Digit : constant Natural := Digit_Value (Value (Index));
            begin
               if Result > (16 - Digit) / 10 then
                  return 0;
               end if;
               Result := Result * 10 + Digit;
            end;
         end if;
      end loop;
      return Result;
   end Base_Of;

   function Valid_Numeric (Value : String) return Boolean is
      First_Hash : Natural := 0;
      Second_Hash : Natural := 0;
      Point : Natural := 0;
      Exponent : Natural := 0;
   begin
      if Value'Length = 0 or else Value (Value'First) not in '0' .. '9' then
         return False;
      end if;
      for Index in Value'Range loop
         if Value (Index) = '#' then
            if First_Hash = 0 then
               First_Hash := Index;
            elsif Second_Hash = 0 then
               Second_Hash := Index;
            else
               return False;
            end if;
         end if;
      end loop;
      if First_Hash > 0 then
         if Second_Hash = 0 then
            return False;
         end if;
         declare
            Base : constant Natural :=
              Base_Of (Value, Value'First, First_Hash - 1);
         begin
            if Base not in 2 .. 16 then
               return False;
            end if;
            for Index in First_Hash + 1 .. Second_Hash - 1 loop
               if Value (Index) = '.' then
                  if Point > 0 then
                     return False;
                  end if;
                  Point := Index;
               end if;
            end loop;
            if Point = 0 then
               if not Valid_Sequence
                 (Value, First_Hash + 1, Second_Hash - 1, Base)
               then
                  return False;
               end if;
            elsif not Valid_Sequence
              (Value, First_Hash + 1, Point - 1, Base)
              or else not Valid_Sequence
                (Value, Point + 1, Second_Hash - 1, Base)
            then
               return False;
            end if;
         end;
         return Second_Hash = Value'Last
           or else Exponent_Is_Valid
             (Value, Second_Hash + 1, Value'Last);
      end if;

      for Index in Value'Range loop
         if Value (Index) = '.' then
            if Point > 0 or else Exponent > 0 then
               return False;
            end if;
            Point := Index;
         elsif Value (Index) in 'e' | 'E' then
            if Exponent > 0 then
               return False;
            end if;
            Exponent := Index;
         end if;
      end loop;
      declare
         Mantissa_Last : constant Integer :=
           (if Exponent = 0 then Value'Last else Exponent - 1);
         Mantissa_Valid : constant Boolean :=
           (if Point = 0
            then Valid_Sequence (Value, Value'First, Mantissa_Last, 10)
            else Valid_Sequence (Value, Value'First, Point - 1, 10)
              and then Valid_Sequence
                (Value, Point + 1, Mantissa_Last, 10));
      begin
         return Mantissa_Valid
           and then
             (Exponent = 0
              or else Exponent_Is_Valid (Value, Exponent, Value'Last));
      end;
   end Valid_Numeric;
end Giflib_Tooling.Token_Lexemes;
