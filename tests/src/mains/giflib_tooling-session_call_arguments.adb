with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_State.Resolution;

package body Giflib_Tooling.Session_Call_Arguments is
   use Ada.Strings.Unbounded;
   use State;
   package State_Resolution renames Giflib_Tooling.Session_State.Resolution;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      Callable_Index : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Resolver_Access) return Argument_Analysis
   is
      Result : Argument_Analysis :=
        (Valid => True, Closing => Callable_Index, Types => <>);
      Parenthesis_Depth : Natural := 0;
      Segment_Depth : Natural := 0;
      Segment_First : Natural := Callable_Index + 2;

      procedure Include (First : Positive; Last : Positive) is
         Value_First : Positive := First;
         Arrow : Source.Optional_Position;
         Nested : Natural := 0;
         Value : Unbounded_String;
      begin
         if First > Last then
            return;
         end if;
         for Cursor in First .. Last loop
            Budgets.Charge (Budget);
            if Source.Image (Tokens (Cursor)) = "(" then
               Nested := Nested + 1;
            elsif Source.Image (Tokens (Cursor)) = ")" and then Nested > 0 then
               Nested := Nested - 1;
            elsif Nested = 0 and then Source.Image (Tokens (Cursor)) = "=>" then
               Arrow := (Present => True, Value => Cursor);
               exit;
            end if;
         end loop;
         if Arrow.Present and then Arrow.Value < Last then
            Value_First := Arrow.Value + 1;
         end if;
         if Value_First = Last then
            case Source.Kind_Of (Tokens (Value_First)) is
               when Source.Numeric_Literal =>
                  Value := To_Unbounded_String ("#numeric");
               when Source.String_Literal =>
                  Value := To_Unbounded_String ("#string");
               when Source.Character_Literal =>
                  Value := To_Unbounded_String ("#character");
               when Source.Identifier =>
                  Value := State_Resolution.Visible_Relation
                    (Object, Object_Binding,
                     Source.Image (Tokens (Value_First)),
                     Budget).Declared_Type;
               when Source.Reserved_Word =>
                  if Source.Image (Tokens (Value_First)) in "true" | "false" then
                     Value := To_Unbounded_String ("#boolean");
                  end if;
               when Source.Symbol =>
                  null;
            end case;
         else
            Value := Resolve
              (Tokens, Value_First, Last, Object, Budget).Declared_Type;
         end if;
         Result.Types.Append (Value);
      end Include;
   begin
      if Callable_Index >= Last
        or else Source.Image (Tokens (Callable_Index + 1)) /= "("
      then
         return Result;
      end if;
      for Cursor in Callable_Index + 1 .. Last loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Parenthesis_Depth := Parenthesis_Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" then
            if Parenthesis_Depth = 1 then
               Result.Closing := Cursor;
               exit;
            elsif Parenthesis_Depth > 0 then
               Parenthesis_Depth := Parenthesis_Depth - 1;
            end if;
         end if;
      end loop;
      if Result.Closing = Callable_Index then
         return (Valid => False);
      end if;
      for Cursor in Callable_Index + 2 .. Result.Closing - 1 loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Segment_Depth := Segment_Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")"
           and then Segment_Depth > 0
         then
            Segment_Depth := Segment_Depth - 1;
         elsif Segment_Depth = 0
           and then Source.Image (Tokens (Cursor)) = ","
         then
            Include (Positive (Segment_First), Cursor - 1);
            Segment_First := Cursor + 1;
         end if;
      end loop;
      if Segment_First < Result.Closing then
         Include (Positive (Segment_First), Result.Closing - 1);
      end if;
      return Result;
   end Analyze;
end Giflib_Tooling.Session_Call_Arguments;
