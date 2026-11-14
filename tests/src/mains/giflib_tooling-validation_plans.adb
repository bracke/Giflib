with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

package body Giflib_Tooling.Validation_Plans is
   use Ada.Strings.Unbounded;
   package Inventory_Keys is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type => String,
      Hash => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   procedure Require_Valid
     (Limits : Giflib_Tooling.Source_Limits.Analysis_Limits) is
   begin
      if Limits.Parsing.Maximum_Model_Storage >
        Limits.Cache.Maximum_Cached_Model_Units
      then
         raise Input_Error with
           "per-source model storage exceeds repository cache storage";
      elsif Limits.Cache.Maximum_Cache_Work >
        Limits.Validation.Maximum_Validation_Work
      then
         raise Input_Error with
           "cache work limit exceeds aggregate validation work limit";
      end if;
   end Require_Valid;

   function Create
     (Documentation_Path : String;
      Test_Directory : String;
      Suite_Path : String;
      Projects : Project_Inventory_Vectors.Vector;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits) return Plan is
      Seen : Inventory_Keys.Set;
   begin
      Require_Valid (Limits);
      if Documentation_Path'Length = 0
        or else Test_Directory'Length = 0
        or else Suite_Path'Length = 0
        or else Projects.Is_Empty
      then
         raise Input_Error with "validation plan paths and projects are required";
      elsif Documentation_Path'Length > Maximum_Path_Length
        or else Test_Directory'Length > Maximum_Path_Length
        or else Suite_Path'Length > Maximum_Path_Length
        or else Natural (Projects.Length) > Maximum_Projects
      then
         raise Input_Error with "validation plan inventory limit exceeded";
      end if;
      for Project of Projects loop
         if Length (Project.Project_Path) = 0
           or else Length (Project.Source_Directory) = 0
         then
            raise Input_Error with
              "validation project paths and source directories are required";
         elsif Length (Project.Project_Path) > Maximum_Path_Length
           or else Length (Project.Source_Directory) > Maximum_Path_Length
         then
            raise Input_Error with "validation project path limit exceeded";
         end if;
         declare
            Project_Path : constant String := To_String (Project.Project_Path);
            Source_Directory : constant String :=
              To_String (Project.Source_Directory);
            Key : constant String :=
              Natural'Image (Project_Path'Length) & ":" & Project_Path &
              Source_Directory;
         begin
            if Seen.Contains (Key) then
               raise Input_Error with "duplicate validation project inventory";
            end if;
            Seen.Insert (Key);
         end;
      end loop;
      return Result : Plan (Configured => True) do
         Result.Limits := Limits;
         Result.Documentation_Path := To_Unbounded_String (Documentation_Path);
         Result.Test_Directory := To_Unbounded_String (Test_Directory);
         Result.Suite_Path := To_Unbounded_String (Suite_Path);
         Result.Projects := Projects;
      end return;
   end Create;

   function Default_Plan return Plan is
      Projects : Project_Inventory_Vectors.Vector;
   begin
      Projects.Append
        (Project_Inventory'
           (To_Unbounded_String ("tests/unit_tests.gpr"),
            To_Unbounded_String ("tests/src/test_mains")));
      Projects.Append
        (Project_Inventory'
           (To_Unbounded_String ("tests/tools.gpr"),
            To_Unbounded_String ("tests/src/mains")));
      return Create
        ("docs/IMPLEMENTATION_PLAN.md", "tests/src",
         "tests/src/giflib-testing-suite.adb", Projects);
   end Default_Plan;

   function With_Limits
     (Object : Plan;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits) return Plan is
   begin
      return Create
        (To_String (Object.Documentation_Path),
         To_String (Object.Test_Directory),
         To_String (Object.Suite_Path), Object.Projects, Limits);
   end With_Limits;

   function Limits_Of
     (Object : Plan) return Giflib_Tooling.Source_Limits.Analysis_Limits is
     (Object.Limits);

   function Documentation_Path_Of (Object : Plan) return String is
     (To_String (Object.Documentation_Path));

   function Test_Directory_Of (Object : Plan) return String is
     (To_String (Object.Test_Directory));

   function Suite_Path_Of (Object : Plan) return String is
     (To_String (Object.Suite_Path));

   procedure Visit_Projects
     (Object : Plan;
      Process : not null access procedure
        (Project_Path : String; Source_Directory : String)) is
   begin
      for Project of Object.Projects loop
         Process
           (To_String (Project.Project_Path),
            To_String (Project.Source_Directory));
      end loop;
   end Visit_Projects;
end Giflib_Tooling.Validation_Plans;
