with Ada.Strings.Unbounded;

with Giflib_Tooling.Declaration_Analysis;
with Giflib_Tooling.Source_Tokens;

package body Giflib_Tooling.Record_Analysis is
   package Declarations renames Giflib_Tooling.Declaration_Analysis;
   package Source renames Giflib_Tooling.Source_Model;

   function Fields
     (Parsed : Source.Parsed_Source;
      Type_Name : String) return Syntax.Name_Vectors.Vector
   is
      Result : Syntax.Name_Vectors.Vector;
      procedure Include
        (Name : Ada.Strings.Unbounded.Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive)
      is
         pragma Unreferenced (Type_First, Type_Last);
      begin
         Result.Append (Name);
      end Include;
      procedure Inspect
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector) is
      begin
         Declarations.Inspect_Record (Tokens, Type_Name, Include'Access);
      end Inspect;
   begin
      Source.Inspect_Tokens (Parsed, Inspect'Access);
      return Result;
   end Fields;
end Giflib_Tooling.Record_Analysis;
