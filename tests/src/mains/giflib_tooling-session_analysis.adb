with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Scanner;

package body Giflib_Tooling.Session_Analysis is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Scanner renames Giflib_Tooling.Session_Scanner;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   use Giflib_Tooling.Name_Collections;
   use Giflib_Tooling.Source_Tokens;
   use Semantics;

   procedure Scan
     (Parsed : Source.Parsed_Source;
      Target_Type : Identity.Target;
      Type_Context : Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Statement : Token_Vectors.Vector;
         Session_Names : Name_Vectors.Vector);
      Unit_Scope : String := "")
   is
      Ignored : Type_Classification_Vectors.Vector;
   begin
      Scanner.Scan
        (Parsed,
         (Target_Type => Target_Type,
          Initial_Context => Type_Context,
          Context_Seed => Scanner.Discover_New_Declarations,
          Unit_Scope => Ada.Strings.Unbounded.To_Unbounded_String (Unit_Scope)),
         Ignored,
         Budget => Budget, Process => Process);
   end Scan;

end Giflib_Tooling.Session_Analysis;
