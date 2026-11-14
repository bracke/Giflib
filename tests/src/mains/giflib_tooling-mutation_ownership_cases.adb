with Project_Tools.Files;
with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Ownership_Cases is
   package Files renames Project_Tools.Files;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   procedure Add_Local_Ownership (Fixture : String) is
   begin
      Sources.Replace_Text
        (Files.Join (Fixture, "src/giflib-internal-lzw.ads"),
         "   package Workspace_Ownership is new "
         & "Giflib.Internal.Owned_Objects" & LF
         & "     (Workspace);",
         "   package Workspace_Ownership is new "
         & "Giflib.Internal.Owned_Objects" & LF
         & "     (Workspace);" & LF
         & "   package Extra_Workspace_Ownership is new Owned_Objects" & LF
         & "     (Workspace);");
   end Add_Local_Ownership;

   procedure Nest_Reviewed_Ownership (Fixture : String) is
      Path : constant String :=
        Files.Join (Fixture, "src/giflib-internal-lzw.ads");
      Body_Path : constant String :=
        Files.Join (Fixture, "src/giflib-internal-lzw.adb");
   begin
      Sources.Replace_Text
        (Path,
         "   package Workspace_Ownership is new "
         & "Giflib.Internal.Owned_Objects" & LF
         & "     (Workspace);" & LF
         & "   type Workspace_Handle is limited record" & LF
         & "      Owner : Workspace_Ownership.Handle;",
         "   package Nested_Ownership is" & LF
         & "      package Workspace_Ownership is new "
         & "Giflib.Internal.Owned_Objects" & LF
         & "        (Workspace);" & LF
         & "   end Nested_Ownership;" & LF
         & "   type Workspace_Handle is limited record" & LF
         & "      Owner : Nested_Ownership.Workspace_Ownership.Handle;");
      Sources.Replace_Text
        (Body_Path,
         "new Workspace_Ownership.Result_Operations",
         "new Nested_Ownership.Workspace_Ownership.Result_Operations");
      Sources.Replace_Text
        (Body_Path,
         "(Workspace_Ownership.Ensure",
         "(Nested_Ownership.Workspace_Ownership.Ensure");
      Sources.Replace_Text
        (Body_Path,
         "(Workspace_Ownership.Release",
         "(Nested_Ownership.Workspace_Ownership.Release");
      Sources.Replace_Text
        (Body_Path,
         "(Workspace_Ownership.Is_Allocated",
         "(Nested_Ownership.Workspace_Ownership.Is_Allocated");
   end Nest_Reviewed_Ownership;
end Giflib_Tooling.Mutation_Ownership_Cases;
