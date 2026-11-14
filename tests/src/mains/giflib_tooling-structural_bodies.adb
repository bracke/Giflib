
package body Giflib_Tooling.Structural_Bodies is

   function Is_Body_Marker
     (Tokens : Source.Token_Vectors.Vector; Index : Positive) return Boolean is
     (Source.Image (Tokens (Index)) = "is"
      and then
        (Index = Tokens.Last_Index
         or else Source.Image (Tokens (Index + 1)) not in
           "separate" | "new" | "abstract" | "null" | "<>"));

   function Introduces_Body
     (Tokens : Source.Token_Vectors.Vector;
      Start : Positive;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean
   is
      Parentheses : Natural := 0;
   begin
      if Start >= Tokens.Last_Index then
         return False;
      end if;
      for Cursor in Start + 1 .. Tokens.Last_Index loop
         Giflib_Tooling.Work_Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Parentheses := Parentheses + 1;
         elsif Source.Image (Tokens (Cursor)) = ")"
           and then Parentheses > 0
         then
            Parentheses := Parentheses - 1;
         elsif Parentheses = 0
           and then Source.Image (Tokens (Cursor)) = ";"
         then
            return False;
         elsif Parentheses = 0
           and then Source.Image (Tokens (Cursor)) = "is"
         then
            return Is_Body_Marker (Tokens, Cursor);
         end if;
      end loop;
      return False;
   end Introduces_Body;
end Giflib_Tooling.Structural_Bodies;
