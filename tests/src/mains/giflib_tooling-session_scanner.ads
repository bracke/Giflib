with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Session_Scanner is
   type Context_Seed_Mode is
     (Discover_New_Declarations, Include_Initial_Context);
   type Scan_Request is record
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Initial_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Context_Seed : Context_Seed_Mode := Discover_New_Declarations;
      Unit_Scope : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   procedure Scan
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Request : Scan_Request;
      Discovered_Context : in out
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector));
end Giflib_Tooling.Session_Scanner;

