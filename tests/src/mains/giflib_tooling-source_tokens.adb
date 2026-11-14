package body Giflib_Tooling.Source_Tokens is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Token_Values.Token_Kind;

   function Image (Item : Token) return String is
      Value : constant String := To_String (Text_Of (Item));
      Result : Unbounded_String;
   begin
      if Kind_Of (Item) /= String_Literal then
         return Value;
      end if;
      Append (Result, '"');
      for Character of Value loop
         Append (Result, Character);
         if Character = '"' then
            Append (Result, '"');
         end if;
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Image;

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

end Giflib_Tooling.Source_Tokens;
