with Ada.Strings.Unbounded;

with Giflib_Tooling.Structural_Bodies;

package body Giflib_Tooling.Structural_Subprograms is
   use Ada.Strings.Unbounded;
   package Bodies renames Giflib_Tooling.Structural_Bodies;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      Start : Positive;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Subprogram_Info
   is
      Result : Subprogram_Info;
      Parentheses : Natural := 0;
   begin
      for Cursor in Start .. Tokens.Last_Index loop
         Giflib_Tooling.Work_Budgets.Charge (Budget);
         declare
            Value : constant String := Source.Image (Tokens (Cursor));
         begin
            if Cursor > Start and then Parentheses = 0 then
               if Value = "return" then
                  Result.Return_Marker := (Present => True, Value => Cursor);
               end if;
               if not Result.Declaration_Last.Present
                 and then Value in "is" | "renames" | "with" | ";"
               then
                  Result.Declaration_Last :=
                    (Present => True, Value => Cursor - 1);
               end if;
               if Value = "is" then
                  Result.Is_Body := Bodies.Is_Body_Marker (Tokens, Cursor);
                  Result.Introduces_Scope := Result.Is_Body
                    and then
                      (Cursor = Tokens.Last_Index
                       or else Source.Image (Tokens (Cursor + 1)) not in
                         "(" | "[");
                  exit;
               elsif Value in "renames" | ";" then
                  exit;
               end if;
            end if;
            if Length (Result.Profile) > 0 then
               Append (Result.Profile, " ");
            end if;
            Append (Result.Profile, Value);
            if Value = "(" then
               Parentheses := Parentheses + 1;
            elsif Value = ")" and then Parentheses > 0 then
               Parentheses := Parentheses - 1;
            end if;
         end;
      end loop;
      return Result;
   end Analyze;

end Giflib_Tooling.Structural_Subprograms;
