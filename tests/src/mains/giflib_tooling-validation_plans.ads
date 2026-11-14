with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Limits;

private package Giflib_Tooling.Validation_Plans is
   Maximum_Path_Length : constant := 1_024;
   Maximum_Projects : constant := 64;
   type Project_Inventory is record
      Project_Path : Ada.Strings.Unbounded.Unbounded_String;
      Source_Directory : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   package Project_Inventory_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Project_Inventory);

   type Plan (<>) is private;

   function Create
     (Documentation_Path : String;
      Test_Directory : String;
      Suite_Path : String;
      Projects : Project_Inventory_Vectors.Vector;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits) return Plan;
   function Default_Plan return Plan;
   function With_Limits
     (Object : Plan;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits) return Plan;
   function Limits_Of
     (Object : Plan) return Giflib_Tooling.Source_Limits.Analysis_Limits;
   function Documentation_Path_Of (Object : Plan) return String;
   function Test_Directory_Of (Object : Plan) return String;
   function Suite_Path_Of (Object : Plan) return String;
   procedure Visit_Projects
     (Object : Plan;
      Process : not null access procedure
        (Project_Path : String; Source_Directory : String));
private
   type Plan (Configured : Boolean) is record
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Documentation_Path : Ada.Strings.Unbounded.Unbounded_String;
      Test_Directory : Ada.Strings.Unbounded.Unbounded_String;
      Suite_Path : Ada.Strings.Unbounded.Unbounded_String;
      Projects : Project_Inventory_Vectors.Vector;
   end record;
end Giflib_Tooling.Validation_Plans;
