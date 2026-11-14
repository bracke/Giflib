package body Giflib_Tooling.Mutation_Types is
   function Create
     (Id : Mutation_Id;
      Name : String;
      Expected : String;
      Compile_First : Boolean) return Mutation_Case
   is
      use Ada.Strings.Unbounded;
   begin
      return
        (Id => Id,
         Name => To_Unbounded_String (Name),
         Expected => To_Unbounded_String (Expected),
         Compile_Project =>
           To_Unbounded_String
             ((if Compile_First then "giflib.gpr" else "")));
   end Create;

   function Create
     (Id : Mutation_Id;
      Name : String;
      Expected : String;
      Compile_Project : String) return Mutation_Case
   is
      use Ada.Strings.Unbounded;
   begin
      return
        (Id => Id,
         Name => To_Unbounded_String (Name),
         Expected => To_Unbounded_String (Expected),
         Compile_Project => To_Unbounded_String (Compile_Project));
   end Create;

   function Definition (Id : Mutation_Id) return Mutation_Case is
   begin
      case Id is
         when Object_Alias =>
            return Create (Id, "object-alias",
                           "session state mutation", True);
         when Local_Helper =>
            return Create (Id, "local-helper",
                           "nested declaration", True);
         when Literal_Keyword =>
            return Create (Id, "literal-keyword",
                           "session state mutation", True);
         when Alternate_Session_Name =>
            return Create (Id, "alternate-session-name",
                           "session state mutation", True);
         when Subtype_Session_Name =>
            return Create (Id, "subtype-session-name",
                           "session state mutation", True);
         when Inherited_Subtype =>
            return Create (Id, "inherited-subtype",
                           "session state mutation", True);
         when Access_Alias =>
            return Create (Id, "access-alias",
                           "session state mutation", True);
         when Access_Session =>
            return Create (Id, "access-session",
                           "session state mutation", True);
         when Indexed_Access_Alias =>
            return Create (Id, "indexed-access-alias",
                           "session state mutation", True);
         when Address_Alias =>
            return Create (Id, "address-alias",
                           "session state mutation", True);
         when Component_Iterator =>
            return Create (Id, "component-iterator",
                           "session state mutation", True);
         when Callable_Iterator =>
            return Create (Id, "callable-iterator",
                           "session state mutation", True);
         when Unused_Reviewed_Alias =>
            return Create (Id, "unused-reviewed-alias",
                           "stale transition approvals", True);
         when Local_Ownership =>
            return Create (Id, "local-ownership",
                           "ownership generic must be fully qualified", True);
         when Nested_Ownership =>
            return Create
              (Id, "nested-ownership",
               "ownership generic must be declared at package unit level",
               True);
         when Duplicate_Source_Basename =>
            return Create (Id, "duplicate-source-basename",
                           "duplicate source unit basename", False);
         when Misplaced_Subunit =>
            return Create (Id, "misplaced-subunit",
                           "subunit is outside an approved directory", False);
         when Misplaced_Test_Body =>
            return Create (Id, "misplaced-test-body",
                           "test source is outside an approved directory", False);
         when Invalid_Test_Subunit =>
            return Create (Id, "invalid-test-subunit",
                           "non-subunit is in subunits", False);
         when Invalid_Tooling_Subunit =>
            return Create (Id, "invalid-tooling-subunit",
                           "non-subunit is in tooling_subunits", False);
         when Interface_Decoy =>
            return Create (Id, "interface-decoy",
                           "library interface unit inventory", False);
         when Unchecked_Main =>
            return Create (Id, "unchecked-main",
                           "does not import project_tools", False);
         when Oversized_Tooling_Main =>
            return Create (Id, "oversized-tooling-main",
                           "test or tooling source exceeds 500 lines", False);
         when Missing_Suite_Registration =>
            return Create (Id, "missing-suite-registration",
                           "not added to suite", False);
         when Wrong_Suite_Receiver =>
            return Create (Id, "wrong-suite-receiver",
                           "not added to suite", "tests/unit_tests.gpr");
         when Duplicate_Suite_Registration =>
            return Create (Id, "duplicate-suite-registration",
                           "added to suite more than once",
                           "tests/unit_tests.gpr");
         when Unknown_Suite_Registration =>
            return Create (Id, "unknown-suite-registration",
                           "suite adds an unknown test package", False);
         when Unlisted_Main =>
            return Create (Id, "unlisted-main",
                           "does not list main source", False);
         when Duplicate_Main =>
            return Create (Id, "duplicate-main",
                           "lists duplicate main source", False);
         when Stale_Documented_Executable =>
            return Create (Id, "stale-documented-executable",
                           "documents stale tool executable", False);
         when Duplicate_Documented_Executable =>
            return Create (Id, "duplicate-documented-executable",
                           "contains duplicate tool executable", False);
         when Invalid_Main_Declaration =>
            return Create (Id, "invalid-main-declaration",
                           "main entry does not declare its procedure",
                           "tests/mutation_main.gpr");
         when Wrong_Workspace_Pin =>
            return Create (Id, "wrong-workspace-pin",
                           "missing the project_tools workspace pin", False);
         when API_Boundary =>
            return Create (Id, "api-boundary",
                           "private API probe unexpectedly compiled", False);
      end case;
   end Definition;

   function All_Cases return Mutation_Case_Array is
      Result : Mutation_Case_Array
        (1 .. Mutation_Id'Pos (Mutation_Id'Last) + 1);
   begin
      for Id in Mutation_Id loop
         Result (Mutation_Id'Pos (Id) + 1) := Definition (Id);
      end loop;
      return Result;
   end All_Cases;
end Giflib_Tooling.Mutation_Types;
