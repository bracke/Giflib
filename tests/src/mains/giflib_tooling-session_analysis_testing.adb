with Giflib_Tooling.Session_Analysis;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Session_Analysis_Testing is
   procedure Scan
     (Text : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Type_Context :
        Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector);
      Unit_Scope : String := "")
   is
      Parsed : constant Giflib_Tooling.Source_Model.Parsed_Source :=
        Giflib_Tooling.Source_Model.Parse (Text);
      Budget : Giflib_Tooling.Work_Budgets.Budget;
   begin
      Giflib_Tooling.Session_Analysis.Scan
        (Parsed, Target_Type, Type_Context, Budget, Process, Unit_Scope);
   end Scan;
end Giflib_Tooling.Session_Analysis_Testing;
