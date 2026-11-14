with Project_Tools.Text;

package body Giflib_Tooling.Suite_Registration_Syntax is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   package Flow renames Giflib_Tooling.Suite_Flow;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Qualified_Test_Unit
     (Items : Tokens.Token_Vectors.Vector;
      First : Positive) return Name_Result
   is
      Name : Unbounded_String;
      Cursor : Positive := First;
      Expect_Identifier : Boolean := True;
   begin
      while Cursor <= Items.Last_Index loop
         if Expect_Identifier
           and then Tokens.Kind_Of (Items (Cursor)) = Tokens.Identifier
         then
            Append (Name, Tokens.Image (Items (Cursor)));
            Expect_Identifier := False;
         elsif not Expect_Identifier
           and then Tokens.Image (Items (Cursor)) = "."
         then
            Append (Name, ".");
            Expect_Identifier := True;
         else
            exit;
         end if;
         Cursor := Cursor + 1;
      end loop;
      declare
         Value : constant String := To_String (Name);
      begin
         if not Expect_Identifier
           and then Value'Length > 5
           and then Project_Tools.Text.Ends_With (Value, ".test")
         then
            return
              (Kind => Name_Found,
               Value => To_Unbounded_String
                 (Value (Value'First .. Value'Last - 5)));
         end if;
         return (Kind => Name_Absent);
      end;
   end Qualified_Test_Unit;

   function Returned_Suite_Name
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Tokens.Token_Vectors.Vector;
      Map : Flow.Flow_Map) return Name_Result
   is
      Value : Unbounded_String;
      Found : Boolean := False;
   begin
      if not Selected.Found
        or else Selected.Last <= Selected.Body_First + 2
      then
         return (Kind => Name_Absent);
      end if;
      for Index in Selected.Body_First + 1 .. Selected.Last - 2 loop
         if not Flow.Is_Nested (Map, Index)
           and then Tokens.Image (Items (Index)) = "return"
           and then Tokens.Kind_Of (Items (Index + 1)) = Tokens.Identifier
           and then Tokens.Image (Items (Index + 2)) = ";"
         then
            if not Found then
               Value := To_Unbounded_String
                 (Tokens.Image (Items (Index + 1)));
               Found := True;
            elsif To_String (Value) /= Tokens.Image (Items (Index + 1)) then
               return (Kind => Name_Ambiguous);
            end if;
         end if;
      end loop;
      return
        (if Found
         then (Kind => Name_Found, Value => Value)
         else (Kind => Name_Absent));
   end Returned_Suite_Name;
end Giflib_Tooling.Suite_Registration_Syntax;
