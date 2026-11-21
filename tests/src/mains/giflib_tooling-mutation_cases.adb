with Giflib_Tooling.Mutation_Configuration_Cases;
with Giflib_Tooling.Mutation_Inventory_Cases;
with Giflib_Tooling.Mutation_Layout_Cases;
with Giflib_Tooling.Mutation_Ownership_Cases;
with Giflib_Tooling.Mutation_Policy_Cases;
with Giflib_Tooling.Mutation_Session_Cases;
with Giflib_Tooling.Mutation_Suite_Cases;

package body Giflib_Tooling.Mutation_Cases is
   package Types renames Giflib_Tooling.Mutation_Types;
   package Configuration_Cases renames
     Giflib_Tooling.Mutation_Configuration_Cases;
   package Inventory_Cases renames
     Giflib_Tooling.Mutation_Inventory_Cases;
   package Layout_Cases renames Giflib_Tooling.Mutation_Layout_Cases;
   package Ownership_Cases renames
     Giflib_Tooling.Mutation_Ownership_Cases;
   package Session_Cases renames Giflib_Tooling.Mutation_Session_Cases;
   package Policy_Cases renames Giflib_Tooling.Mutation_Policy_Cases;
   package Suite_Cases renames Giflib_Tooling.Mutation_Suite_Cases;

   function All_Cases return Mutation_Case_Array is
   begin
      return Types.All_Cases;
   end All_Cases;

   procedure Apply (Item : Mutation_Case; Fixture : String) is
   begin
      case Item.Id is
         when Types.Object_Alias =>
            Session_Cases.Add_Object_Alias (Fixture);
         when Types.Local_Helper =>
            Session_Cases.Add_Local_Helper (Fixture);
         when Types.Literal_Keyword =>
            Session_Cases.Add_Literal_Keyword (Fixture);
         when Types.Alternate_Session_Name =>
            Session_Cases.Add_Alternate_Session_Name (Fixture);
         when Types.Subtype_Session_Name =>
            Session_Cases.Add_Subtype_Session_Name (Fixture);
         when Types.Inherited_Subtype =>
            Session_Cases.Add_Inherited_Subtype (Fixture);
         when Types.Access_Alias =>
            Session_Cases.Add_Access_Alias (Fixture);
         when Types.Access_Session =>
            Session_Cases.Add_Access_Session (Fixture);
         when Types.Indexed_Access_Alias =>
            Session_Cases.Add_Indexed_Access_Alias (Fixture);
         when Types.Address_Alias =>
            Session_Cases.Add_Address_Alias (Fixture);
         when Types.Component_Iterator =>
            Session_Cases.Add_Component_Iterator (Fixture);
         when Types.Callable_Iterator =>
            Session_Cases.Add_Callable_Iterator (Fixture);
         when Types.Unused_Reviewed_Alias =>
            Policy_Cases.Leave_Reviewed_Alias_Unused (Fixture);
         when Types.Local_Ownership =>
            Ownership_Cases.Add_Local_Ownership (Fixture);
         when Types.Nested_Ownership =>
            Ownership_Cases.Nest_Reviewed_Ownership (Fixture);
         when Types.Duplicate_Source_Basename =>
            Layout_Cases.Add_Duplicate_Source_Basename (Fixture);
         when Types.Misplaced_Subunit =>
            Layout_Cases.Add_Misplaced_Subunit (Fixture);
         when Types.Misplaced_Test_Body =>
            Layout_Cases.Add_Misplaced_Test_Body (Fixture);
         when Types.Invalid_Test_Subunit =>
            Layout_Cases.Add_Invalid_Test_Subunit (Fixture);
         when Types.Invalid_Tooling_Subunit =>
            Layout_Cases.Add_Invalid_Tooling_Subunit (Fixture);
         when Types.Interface_Decoy =>
            Configuration_Cases.Add_Interface_Decoy (Fixture);
         when Types.Unchecked_Main =>
            Inventory_Cases.Add_Unchecked_Main (Fixture);
         when Types.Oversized_Tooling_Main =>
            Layout_Cases.Add_Oversized_Tooling_Main (Fixture);
         when Types.Missing_Suite_Registration =>
            Suite_Cases.Remove_Suite_Registration (Fixture);
         when Types.Wrong_Suite_Receiver =>
            Suite_Cases.Redirect_Suite_Registration (Fixture);
         when Types.Duplicate_Suite_Registration =>
            Suite_Cases.Duplicate_Suite_Registration (Fixture);
         when Types.Unknown_Suite_Registration =>
            Suite_Cases.Add_Unknown_Suite_Registration (Fixture);
         when Types.Unlisted_Main =>
            Inventory_Cases.Remove_Declared_Main (Fixture);
         when Types.Duplicate_Main =>
            Inventory_Cases.Duplicate_Declared_Main (Fixture);
         when Types.Stale_Documented_Executable =>
            Inventory_Cases.Add_Stale_Documented_Executable (Fixture);
         when Types.Duplicate_Documented_Executable =>
            Inventory_Cases.Duplicate_Documented_Executable (Fixture);
         when Types.Invalid_Main_Declaration =>
            Inventory_Cases.Change_Main_Declaration (Fixture);
         when Types.Wrong_Repository_Pin =>
            Configuration_Cases.Change_Repository_Pin (Fixture);
         when Types.API_Boundary =>
            Layout_Cases.Add_API_Boundary_Bypass (Fixture);
      end case;
   end Apply;
end Giflib_Tooling.Mutation_Cases;
