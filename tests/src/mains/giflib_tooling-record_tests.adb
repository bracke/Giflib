with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Record_Analysis;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Model;

package body Giflib_Tooling.Record_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Records renames Giflib_Tooling.Record_Analysis;
   package Source renames Giflib_Tooling.Source_Model;

   procedure Run is
      Fields : constant Giflib_Tooling.Name_Collections.Name_Vectors.Vector :=
        Records.Fields
          (Source.Parse
             ("type Sample is record A : Natural; B : Boolean; end record;"),
           "Sample");
      Discriminated_Fields : constant Giflib_Tooling.Name_Collections.Name_Vectors.Vector :=
        Records.Fields
          (Source.Parse
             ("type Sample (First : Natural; Second : Natural) is record " &
              "Value : Natural; end record;"), "Sample");
      Variant_Fields : constant Giflib_Tooling.Name_Collections.Name_Vectors.Vector :=
        Records.Fields
          (Source.Parse
             ("type Sample (Kind : Boolean) is record case Kind is " &
              "when True => A : Natural; when False => B : Natural; " &
              "end case; end record;"), "Sample");
   begin
      Check.Check
        (Natural (Fields.Length) = 2
         and then Giflib_Tooling.Name_Collections.Contains (Fields, "a")
         and then Giflib_Tooling.Name_Collections.Contains (Fields, "b"),
         "record field derivation");
      Check.Check
        (Natural (Discriminated_Fields.Length) = 1
         and then Giflib_Tooling.Name_Collections.Contains (Discriminated_Fields, "value"),
         "multi-discriminant record ownership");
      Check.Check
        (Natural (Variant_Fields.Length) = 2
         and then Giflib_Tooling.Name_Collections.Contains (Variant_Fields, "a")
         and then Giflib_Tooling.Name_Collections.Contains (Variant_Fields, "b"),
         "variant record component isolation");
   end Run;
end Giflib_Tooling.Record_Tests;
