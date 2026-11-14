with Giflib_Tooling.Suite_Registration_Syntax;

package body Giflib_Tooling.Suite_Allocation_Discovery is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   use type Giflib_Tooling.Suite_Registration_Syntax.Name_Result_Kind;
   package Flow renames Giflib_Tooling.Suite_Flow;
   package Syntax renames Giflib_Tooling.Suite_Registration_Syntax;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Allocation_Name
     (Items : Tokens.Token_Vectors.Vector;
      Selection_First : Positive;
      New_Index : Positive) return Syntax.Name_Result
   is
      Cursor : Natural := New_Index;
   begin
      while Cursor > Selection_First loop
         Cursor := Cursor - 1;
         exit when Tokens.Image (Items (Positive (Cursor))) = ";";
         if Tokens.Image (Items (Positive (Cursor))) = ":" then
            if Cursor > Items.First_Index
              and then Tokens.Kind_Of
                (Items (Positive (Cursor - 1))) = Tokens.Identifier
            then
               return
                 (Kind => Syntax.Name_Found,
                  Value => Tokens.Text_Of (Items (Positive (Cursor - 1))));
            end if;
            return (Kind => Syntax.Name_Absent);
         end if;
      end loop;
      return (Kind => Syntax.Name_Absent);
   end Allocation_Name;

   function Discover
     (Selected : Giflib_Tooling.Suite_Source_Selection.Selected_Body;
      Items : Tokens.Token_Vectors.Vector;
      Map : Flow.Flow_Map) return Test_Allocation_Maps.Map
   is
      Result : Test_Allocation_Maps.Map;
   begin
      if not Selected.Found
        or else Selected.Body_First <= Selected.First
      then
         return Result;
      end if;
      for Index in Selected.First .. Selected.Body_First - 1 loop
         if not Flow.Is_Nested (Map, Index)
           and then Tokens.Image (Items (Index)) = "new"
           and then Index < Items.Last_Index
         then
            declare
               Unit_Name : constant Syntax.Name_Result :=
                 Syntax.Qualified_Test_Unit (Items, Index + 1);
               Object_Name : constant Syntax.Name_Result :=
                 Allocation_Name (Items, Selected.First, Index);
            begin
               if Unit_Name.Kind = Syntax.Name_Found
                 and then Object_Name.Kind = Syntax.Name_Found
               then
                  Result.Include
                    (To_String (Object_Name.Value), Unit_Name.Value);
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Discover;
end Giflib_Tooling.Suite_Allocation_Discovery;
