with Ada.Strings.Unbounded;

with Giflib_Tooling.Structural_Bodies;

package body Giflib_Tooling.Source_Queries is
   use Ada.Strings.Unbounded;
   use type Source.Token_Kind;
   package Bodies renames Giflib_Tooling.Structural_Bodies;
   package Units renames Giflib_Tooling.Source_Units;

   function Separate_Marker
     (Tokens : Source.Token_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Natural is
   begin
      for Index in Tokens.First_Index .. Tokens.Last_Index loop
         Giflib_Tooling.Work_Budgets.Charge (Budget);
         if Source.Image (Tokens (Index)) = "separate" then
            return Index;
         elsif Source.Image (Tokens (Index)) in
           "procedure" | "function" | "package" | "task" | "protected"
         then
            return 0;
         end if;
      end loop;
      return 0;
   end Separate_Marker;

   function Separate_Clause_Of
     (Tokens : Source.Token_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Before_Retain : access procedure (Amount : Natural) := null)
      return Giflib_Tooling.Source_Units.Separate_Clause
   is
      Marker : constant Natural := Separate_Marker (Tokens, Budget);
      Expect_Name : Boolean := True;
      Parent_Length : Natural := 0;

      procedure Add_Parent_Length (Amount : Natural) is
      begin
         if Amount > Natural'Last - Parent_Length then
            raise Input_Error with "separate clause length limit exceeded";
         end if;
         Parent_Length := Parent_Length + Amount;
      end Add_Parent_Length;

      function Introduces_Body (Index : Positive) return Boolean is
         Cursor : Positive := Index + 1;
         Introducer : constant Positive := Cursor;
      begin
         if Cursor > Tokens.Last_Index then
            return False;
         elsif Source.Image (Tokens (Cursor)) in "procedure" | "function"
         then
            Cursor := Cursor + 1;
         elsif Source.Image (Tokens (Cursor)) in
           "package" | "task" | "protected"
           and then Cursor + 1 <= Tokens.Last_Index
           and then Source.Image (Tokens (Cursor + 1)) = "body"
         then
            Cursor := Cursor + 2;
         else
            return False;
         end if;
         if Cursor > Tokens.Last_Index
           or else Source.Kind_Of (Tokens (Cursor)) /= Source.Identifier
         then
            return False;
         end if;
         return Bodies.Introduces_Body (Tokens, Introducer, Budget);
      end Introduces_Body;
   begin
      if Marker = 0 then
         return (Kind => Units.No_Separate_Clause);
      elsif Marker = Tokens.Last_Index
        or else Source.Image (Tokens (Marker + 1)) /= "("
        or else Marker + 2 > Tokens.Last_Index
      then
         return (Kind => Units.Malformed_Separate_Clause);
      end if;
      for Index in Marker + 2 .. Tokens.Last_Index loop
         Giflib_Tooling.Work_Budgets.Charge (Budget);
         if Source.Image (Tokens (Index)) = ")" then
            if Expect_Name or else not Introduces_Body (Index) then
               return (Kind => Units.Malformed_Separate_Clause);
            end if;
            if Before_Retain /= null then
               Before_Retain (Parent_Length);
            end if;
            declare
               Result : Unbounded_String;
            begin
               for Part in Marker + 2 .. Index - 1 loop
                  Giflib_Tooling.Work_Budgets.Charge (Budget);
                  Append (Result, Source.Image (Tokens (Part)));
               end loop;
               return
                 (Kind => Units.Valid_Separate_Clause, Parent => Result);
            end;
         elsif Expect_Name
           and then Source.Kind_Of (Tokens (Index)) = Source.Identifier
         then
            Add_Parent_Length (Source.Image (Tokens (Index))'Length);
            Expect_Name := False;
         elsif not Expect_Name
           and then Source.Image (Tokens (Index)) = "."
         then
            Add_Parent_Length (1);
            Expect_Name := True;
         else
            return (Kind => Units.Malformed_Separate_Clause);
         end if;
      end loop;
      return (Kind => Units.Malformed_Separate_Clause);
   end Separate_Clause_Of;

end Giflib_Tooling.Source_Queries;
