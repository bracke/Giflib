with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Scanner;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Tokens;

package body Giflib_Tooling.Session_Queries is
   use Ada.Strings.Unbounded;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Names renames Giflib_Tooling.Name_Collections;
   package Scanner renames Giflib_Tooling.Session_Scanner;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Package_Type_Context
     (Parsed : Source.Parsed_Source;
      Target_Type : Identity.Target;
      Initial_Context : Semantics.Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String := "")
      return Semantics.Type_Classification_Vectors.Vector
   is
      Result : Semantics.Type_Classification_Vectors.Vector;
      procedure Ignore
        (Statement : Tokens.Token_Vectors.Vector;
         Session_Names : Names.Name_Vectors.Vector)
      is
         pragma Unreferenced (Statement, Session_Names);
      begin
         null;
      end Ignore;
   begin
      Scanner.Scan
        (Parsed,
         (Target_Type => Target_Type,
          Initial_Context => Initial_Context,
          Context_Seed => Scanner.Include_Initial_Context,
          Unit_Scope => To_Unbounded_String (Unit_Scope)),
         Result, Budget => Budget, Process => Ignore'Access);
      return Result;
   end Package_Type_Context;

end Giflib_Tooling.Session_Queries;
