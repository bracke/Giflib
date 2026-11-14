with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Queries;
with Giflib_Tooling.Session_Scanner;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Session_Query_Testing is
   use Ada.Strings.Unbounded;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Names renames Giflib_Tooling.Name_Collections;
   package Queries renames Giflib_Tooling.Session_Queries;
   package Scanner renames Giflib_Tooling.Session_Scanner;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Package_Type_Context
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Initial_Context : Semantics.Type_Classification_Vectors.Vector;
      Unit_Scope : String := "")
      return Semantics.Type_Classification_Vectors.Vector
   is
      Budget : Budgets.Budget;
      Parsed : constant Source.Parsed_Source := Source.Parse (Text);
   begin
      return Queries.Package_Type_Context
        (Parsed, Target_Type, Initial_Context, Budget, Unit_Scope);
   end Package_Type_Context;

   function Identifiers
     (Text : String; Target_Type : Giflib_Tooling.Session_Identity.Target)
      return Names.Name_Vectors.Vector
   is
      Result : Names.Name_Vectors.Vector;
      procedure Collect
        (Statement : Tokens.Token_Vectors.Vector;
         Session_Names : Names.Name_Vectors.Vector) is
         pragma Unreferenced (Statement);
      begin
         for Name of Session_Names loop
            if not Names.Contains (Result, To_String (Name)) then
               Result.Append (Name);
            end if;
         end loop;
      end Collect;
      Parsed : constant Source.Parsed_Source := Source.Parse (Text);
      No_Context : Semantics.Type_Classification_Vectors.Vector;
      Ignored : Semantics.Type_Classification_Vectors.Vector;
      Budget : Budgets.Budget;
   begin
      Scanner.Scan
        (Parsed,
         (Target_Type => Target_Type,
          Initial_Context => No_Context,
          Context_Seed => Scanner.Discover_New_Declarations,
          Unit_Scope => Null_Unbounded_String),
         Ignored, Budget => Budget, Process => Collect'Access);
      return Result;
   end Identifiers;

   function Identifiers_At
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Position : Natural) return Names.Name_Vectors.Vector
   is
      Result : Names.Name_Vectors.Vector;
      procedure Capture
        (Statement : Tokens.Token_Vectors.Vector;
         Session_Names : Names.Name_Vectors.Vector) is
         pragma Unreferenced (Statement);
      begin
         Result := Session_Names;
      end Capture;
   begin
      if Text'Length = 0 or else Position = 0 then
         return Result;
      end if;
      declare
         Parsed : constant Source.Parsed_Source :=
           Source.Parse_Through (Text, Position);
         No_Context : Semantics.Type_Classification_Vectors.Vector;
         Ignored : Semantics.Type_Classification_Vectors.Vector;
         Budget : Budgets.Budget;
      begin
         Scanner.Scan
           (Parsed,
            (Target_Type => Target_Type,
             Initial_Context => No_Context,
             Context_Seed => Scanner.Discover_New_Declarations,
             Unit_Scope => Null_Unbounded_String),
            Ignored, Budget => Budget, Process => Capture'Access);
      end;
      return Result;
   end Identifiers_At;
end Giflib_Tooling.Session_Query_Testing;
