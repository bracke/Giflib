with Giflib_Tooling.Session_Types;

package body Giflib_Tooling.Session_Branch_Expressions is
   use State;
   use type Giflib_Tooling.Session_Types.Session_Depth;

   function Case_Result
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Call_Arguments.Resolver_Access) return Relation
   is
      Result : Relation;
      Found : Boolean := False;
      Arrow : Source.Optional_Position;
      Depth : Natural := 0;

      procedure Include (First : Positive; Last : Positive) is
         Item : constant Relation := Resolve
           (Tokens, First, Last, Object, Budget);
      begin
         if not Found or else Item.Depth < Result.Depth then
            Result := Item;
            Found := True;
         end if;
      end Include;
   begin
      for Cursor in First + 1 .. Last loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Depth := Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" and then Depth > 0 then
            Depth := Depth - 1;
         elsif Depth = 0 and then Source.Image (Tokens (Cursor)) = "=>" then
            Arrow := (Present => True, Value => Cursor);
         elsif Depth = 0
           and then Source.Image (Tokens (Cursor)) = "when"
           and then Arrow.Present
           and then Cursor >= Arrow.Value + 3
         then
            Include (Arrow.Value + 1, Cursor - 2);
            Arrow := Source.No_Position;
         end if;
      end loop;
      if Arrow.Present and then Arrow.Value < Last then
         Include (Arrow.Value + 1, Last);
      end if;
      return Result;
   end Case_Result;

   function Conditional_Result
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget;
      Resolve : Call_Arguments.Resolver_Access) return Relation
   is
      Then_Marker : Source.Optional_Position;
      Else_Marker : Source.Optional_Position;
      Parentheses : Natural := 0;
   begin
      for Cursor in First + 1 .. Last loop
         Budgets.Charge (Budget);
         if Source.Image (Tokens (Cursor)) = "(" then
            Parentheses := Parentheses + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" and then Parentheses > 0 then
            Parentheses := Parentheses - 1;
         elsif Parentheses = 0 and then Source.Image (Tokens (Cursor)) = "then" then
            Then_Marker := (Present => True, Value => Cursor);
         elsif Parentheses = 0 and then Source.Image (Tokens (Cursor)) = "else" then
            Else_Marker := (Present => True, Value => Cursor);
            exit;
         end if;
      end loop;
      if Then_Marker.Present
        and then Else_Marker.Present
        and then Else_Marker.Value > Then_Marker.Value + 1
        and then Else_Marker.Value < Last
      then
         declare
            Left : constant Relation :=
              Resolve
                (Tokens, Then_Marker.Value + 1,
                 Else_Marker.Value - 1, Object, Budget);
            Right : constant Relation :=
              Resolve
                (Tokens, Else_Marker.Value + 1, Last, Object, Budget);
         begin
            return (if Left.Depth <= Right.Depth then Left else Right);
         end;
      end if;
      return (others => <>);
   end Conditional_Result;
end Giflib_Tooling.Session_Branch_Expressions;
