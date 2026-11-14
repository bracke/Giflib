with Giflib_Tooling.Suite_Registration_Syntax;

package body Giflib_Tooling.Suite_Registration_Traversal is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   use type Giflib_Tooling.Suite_Registration_Syntax.Name_Result_Kind;
   package Allocation renames Giflib_Tooling.Suite_Allocation_Discovery;
   package Flow renames Giflib_Tooling.Suite_Flow;
   package Syntax renames Giflib_Tooling.Suite_Registration_Syntax;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   procedure Visit
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Tokens.Token_Vectors.Vector;
      Map : Flow.Flow_Map;
      Returned_Suite : Unbounded_String;
      Allocations : Allocation.Test_Allocation_Maps.Map;
      Process : not null access procedure (Unit_Name : String))
   is
   begin
      for Index in Selected.Body_First + 2 .. Selected.Last - 1 loop
         if not Flow.Is_Nested (Map, Index)
           and then Flow.Is_Unconditional (Map, Index)
           and then Tokens.Image (Items (Index - 2)) =
             To_String (Returned_Suite)
           and then Tokens.Image (Items (Index - 1)) = "."
           and then Tokens.Image (Items (Index)) = "add_test"
           and then Tokens.Image (Items (Index + 1)) = "("
         then
            declare
               Cursor : Positive := Index + 2;
               Depth : Natural := 1;
            begin
               while Cursor <= Items.Last_Index and then Depth > 0 loop
                  if Tokens.Image (Items (Cursor)) = "(" then
                     Depth := Depth + 1;
                  elsif Tokens.Image (Items (Cursor)) = ")" then
                     Depth := Depth - 1;
                  elsif Depth = 1
                    and then Tokens.Image (Items (Cursor)) = "new"
                    and then Cursor < Items.Last_Index
                  then
                     declare
                        Unit_Name : constant Syntax.Name_Result :=
                          Syntax.Qualified_Test_Unit (Items, Cursor + 1);
                     begin
                        if Unit_Name.Kind = Syntax.Name_Found then
                           Process (To_String (Unit_Name.Value));
                        end if;
                     end;
                  elsif Depth = 1
                    and then Tokens.Kind_Of (Items (Cursor)) =
                      Tokens.Identifier
                  then
                     declare
                        Object_Name : constant String :=
                          Tokens.Image (Items (Cursor));
                     begin
                        if Allocations.Contains (Object_Name) then
                           Process
                             (To_String (Allocations.Element (Object_Name)));
                        end if;
                     end;
                  end if;
                  Cursor := Cursor + 1;
               end loop;
            end;
         end if;
      end loop;
   end Visit;
end Giflib_Tooling.Suite_Registration_Traversal;
