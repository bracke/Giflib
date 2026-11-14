with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Contexts;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;

package body Giflib_Tooling.Session_Package_Aliases is
   use Ada.Strings.Unbounded;
   use type Source.Token_Kind;
   package Contexts renames Giflib_Tooling.Session_Contexts;
   package Bindings renames Giflib_Tooling.Session_State.Bindings;
   package Scopes renames Giflib_Tooling.Session_State.Scopes;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Object : in out State.State;
      Context : in out Semantics.Type_Classification_Vectors.Vector;
      Budget : in out State.Budgets.Budget;
      Outcome : out Alias_Outcome)
   is
      Renames_Marker : Source.Optional_Position;
      Semicolon : Source.Optional_Position;
      Depth : Natural := 0;
      Target : Unbounded_String;
      Expect_Identifier : Boolean := True;

      function Is_Name (Cursor : Positive) return Boolean is
        (Source.Kind_Of (Tokens (Cursor)) = Source.Identifier);
   begin
      State.Budgets.Charge_Scan
        (Budget,
         (if Index < Tokens.Last_Index
          then 2 * (Tokens.Last_Index - Index)
          else 0));
      Outcome := Not_A_Renaming;
      if Index < Tokens.Last_Index then
         for Cursor in Index + 1 .. Tokens.Last_Index loop
            if Source.Image (Tokens (Cursor)) = "(" then
               Depth := Depth + 1;
            elsif Source.Image (Tokens (Cursor)) = ")" and then Depth > 0 then
               Depth := Depth - 1;
            elsif Depth = 0
              and then Source.Image (Tokens (Cursor)) = "renames"
            then
               Renames_Marker := (Present => True, Value => Cursor);
            elsif Depth = 0 and then Source.Image (Tokens (Cursor)) = ";" then
               Semicolon := (Present => True, Value => Cursor);
               exit;
            end if;
         end loop;
      end if;
      if Renames_Marker.Present then
         Outcome := Invalid_Renaming;
      end if;
      if Index + 1 > Tokens.Last_Index
        or else not Is_Name (Index + 1)
        or else not Renames_Marker.Present
        or else not Semicolon.Present
        or else Semicolon.Value <= Renames_Marker.Value + 1
      then
         return;
      end if;
      for Cursor in Renames_Marker.Value + 1 .. Semicolon.Value - 1 loop
         if Expect_Identifier and then Is_Name (Cursor)
         then
            Append (Target, Source.Image (Tokens (Cursor)));
            Expect_Identifier := False;
         elsif not Expect_Identifier
           and then Source.Image (Tokens (Cursor)) = "."
         then
            Append (Target, ".");
            Expect_Identifier := True;
         else
            return;
         end if;
      end loop;
      if Expect_Identifier then
         return;
      end if;
      Bindings.Bind_Package
        (Object, Source.Image (Tokens (Index + 1)), Budget,
         To_String (Target));
      Outcome := Applied_Renaming;
      if not Scopes.Is_Context_Level (Object) then
         return;
      end if;
      Contexts.Set_Package
        (Context, Source.Text_Of (Tokens (Index + 1)), Target, Budget);
   end Add;
end Giflib_Tooling.Session_Package_Aliases;
