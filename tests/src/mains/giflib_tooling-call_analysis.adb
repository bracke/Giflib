package body Giflib_Tooling.Call_Analysis is
   use Ada.Strings.Unbounded;
   use type Source.Token_Kind;

   function Image (Result : Callee_Result) return String is
     (To_String (Result.Name));

   function Callee_Before
     (Statement : Source.Token_Vectors.Vector;
      Open_Paren : Positive) return Callee_Result
   is
      Result : Unbounded_String;
      First : Positive := Open_Paren;
   begin
      if Open_Paren = Statement.First_Index then
         return (Status => No_Callee);
      end if;
      First := Open_Paren - 1;
      if Source.Kind_Of (Statement (First)) /= Source.Identifier then
         if Source.Image (Statement (First)) in "." | ")" | "all" then
            return (Status => Unrecognized_Callee);
         end if;
         return (Status => No_Callee);
      end if;
      while First >= Statement.First_Index + 2
        and then Source.Image (Statement (First - 1)) = "."
        and then Source.Kind_Of (Statement (First - 2)) = Source.Identifier
      loop
         First := First - 2;
      end loop;
      if First > Statement.First_Index
        and then Source.Image (Statement (First - 1)) = "."
      then
         return (Status => Unrecognized_Callee);
      elsif First > Statement.First_Index
        and then Source.Image (Statement (First - 1)) = "'"
      then
         return (Status => No_Callee);
      end if;
      for Index in First .. Open_Paren - 1 loop
         if Source.Kind_Of (Statement (Index)) /= Source.Identifier
           and then Source.Image (Statement (Index)) /= "."
         then
            return (Status => Unrecognized_Callee);
         end if;
         Append (Result, Source.Image (Statement (Index)));
      end loop;
      return (Status => Callee_Found, Name => Result);
   end Callee_Before;

   function Enclosing_Callee
     (Statement : Source.Token_Vectors.Vector;
      Actual : Positive) return Callee_Result
   is
      Depth : Natural := 0;
   begin
      if Actual = Statement.First_Index then
         return (Status => No_Callee);
      end if;
      for Index in reverse Statement.First_Index .. Actual - 1 loop
         if Source.Image (Statement (Index)) = ")" then
            Depth := Depth + 1;
         elsif Source.Image (Statement (Index)) = "(" then
            if Depth = 0 then
               declare
                  Callee : constant Callee_Result :=
                    Callee_Before (Statement, Index);
               begin
                  if Callee.Status /= No_Callee then
                     return Callee;
                  end if;
               end;
            end if;
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
         end if;
      end loop;
      return (Status => No_Callee);
   end Enclosing_Callee;
end Giflib_Tooling.Call_Analysis;
