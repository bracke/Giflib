with Project_Tools.Files;
with Project_Tools.Test_Fixtures;
with Project_Tools.Text;

package body Giflib_Tooling.Mutation_Sources is
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   LF : constant Character := ASCII.LF;

   procedure Replace_Text
     (Path : String; Before : String; After : String)
   is
      Content : constant String := Files.Read_Raw_File (Path);
      Position : constant Natural := Project_Tools.Text.Index (Content, Before);
   begin
      if Position = 0 then
         Fail ("mutation test failed: mutation anchor is missing: " & Path);
      end if;
      Fixtures.Write_Text_File
        (Path,
         Content (Content'First .. Position - 1) & After &
         Content (Position + Before'Length .. Content'Last));
   end Replace_Text;

   function Reset_Subunit
     (Declarations : String;
      Statements : String;
      Context_Clauses : String := "") return String
   is
      Context : constant String :=
        (if Context_Clauses'Length = 0
         then ""
         else Context_Clauses & LF & LF);
   begin
      return Context &
        "separate (Giflib.Decoding)" & LF &
        "function Reset" & LF &
        "  (Object : in out Decoder;" & LF &
        "   Options : Decode_Options := Default_Options;" & LF &
        "   Constraints : Limits.Limit_Set := Limits.Default_Limits)" & LF &
        "   return Results.Result" & LF &
        "is" & LF &
        Declarations &
        "begin" & LF &
        Statements &
        "   return Initialize (Object, Options, Constraints);" & LF &
        "end Reset;" & LF;
   end Reset_Subunit;
end Giflib_Tooling.Mutation_Sources;
