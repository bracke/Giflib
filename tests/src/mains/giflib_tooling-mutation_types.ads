with Ada.Strings.Unbounded;

private package Giflib_Tooling.Mutation_Types is
   type Mutation_Id is
     (Object_Alias, Local_Helper, Literal_Keyword, Alternate_Session_Name,
      Subtype_Session_Name, Inherited_Subtype, Access_Alias, Access_Session,
      Indexed_Access_Alias, Address_Alias, Component_Iterator,
      Callable_Iterator, Unused_Reviewed_Alias, Local_Ownership,
      Nested_Ownership,
      Duplicate_Source_Basename,
      Misplaced_Subunit, Misplaced_Test_Body,
      Invalid_Test_Subunit, Invalid_Tooling_Subunit,
      Interface_Decoy, Unchecked_Main,
      Oversized_Tooling_Main, Missing_Suite_Registration,
      Wrong_Suite_Receiver, Duplicate_Suite_Registration,
      Unknown_Suite_Registration, Unlisted_Main,
      Duplicate_Main, Stale_Documented_Executable,
      Duplicate_Documented_Executable, Invalid_Main_Declaration,
      Wrong_Repository_Pin, API_Boundary);
   type Mutation_Case is record
      Id : Mutation_Id;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Expected : Ada.Strings.Unbounded.Unbounded_String;
      Compile_Project : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   type Mutation_Case_Array is array (Positive range <>) of Mutation_Case;
   function All_Cases return Mutation_Case_Array;
end Giflib_Tooling.Mutation_Types;
