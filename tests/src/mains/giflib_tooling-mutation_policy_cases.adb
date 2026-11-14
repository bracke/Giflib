with Project_Tools.Files;

with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Policy_Cases is
   package Files renames Project_Tools.Files;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   procedure Replace_Text
     (Path : String; Before : String; After : String)
      renames Sources.Replace_Text;

   procedure Leave_Reviewed_Alias_Unused (Fixture : String) is
      Path : constant String :=
        Files.Join (Fixture, "src/giflib-encoding-frame_pipeline.adb");
   begin
      Replace_Text
        (Path, "        Geometry_Arithmetic.Area",
         "        Internal.Geometry_Arithmetic.Area");
      Replace_Text
        (Path,
         "   package Geometry_Arithmetic renames " &
         "Internal.Geometry_Arithmetic;" & LF,
         "   package Geometry_Arithmetic renames " &
         "Internal.Geometry_Arithmetic;" & LF &
         "   pragma Unreferenced (Geometry_Arithmetic);" & LF);
   end Leave_Reviewed_Alias_Unused;

end Giflib_Tooling.Mutation_Policy_Cases;
