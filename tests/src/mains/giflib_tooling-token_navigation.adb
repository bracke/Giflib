package body Giflib_Tooling.Token_Navigation is
   function Before_Semicolon
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Value : String;
      Budget : in out Budgets.Budget) return Optional_Position
   is
   begin
      for Cursor in First .. Tokens.Last_Index loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = Value then
            return (Present => True, Value => Cursor);
         end if;
         exit when Source.Image (Tokens (Cursor)) = ";";
      end loop;
      return (Present => False);
   end Before_Semicolon;

   function Before_Outer_Semicolon
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Value : String;
      Budget : in out Budgets.Budget) return Optional_Position
   is
      Depth : Natural := 0;
   begin
      for Cursor in First .. Tokens.Last_Index loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Depth := Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" and then Depth > 0 then
            Depth := Depth - 1;
         elsif Depth = 0 and then Source.Image (Tokens (Cursor)) = Value then
            return (Present => True, Value => Cursor);
         elsif Depth = 0 and then Source.Image (Tokens (Cursor)) = ";" then
            exit;
         end if;
      end loop;
      return (Present => False);
   end Before_Outer_Semicolon;

   function Is_Outer_Group
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Budget : in out Budgets.Budget) return Boolean
   is
      Depth : Natural := 0;
   begin
      if First >= Last
        or else Source.Image (Tokens (First)) /= "("
        or else Source.Image (Tokens (Last)) /= ")"
      then
         return False;
      end if;
      for Cursor in First .. Last loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Depth := Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" then
            if Depth = 0 then
               return False;
            end if;
            Depth := Depth - 1;
            if Depth = 0 and then Cursor < Last then
               return False;
            end if;
         end if;
      end loop;
      return Depth = 0;
   end Is_Outer_Group;
end Giflib_Tooling.Token_Navigation;
