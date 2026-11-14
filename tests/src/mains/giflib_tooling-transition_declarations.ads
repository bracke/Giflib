with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Transition_Policy;
with Giflib_Tooling.Validation_Storage_Budgets;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Transition_Declarations is
   package Source renames Giflib_Tooling.Source_Model;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Collect_Visible
     (Parsed : Source.Parsed_Source;
      Names : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Storage : in out
        Giflib_Tooling.Validation_Storage_Budgets.Transaction);
   procedure Collect_Types
     (Parsed : Source.Parsed_Source;
      Names : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Storage : in out
        Giflib_Tooling.Validation_Storage_Budgets.Transaction);

   procedure Check
     (Parsed : Source.Parsed_Source;
      Unit_Name : String;
      Policy_Set : Giflib_Tooling.Transition_Policy.Policy;
      Trusted_Local_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Seen_Aliases : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Budget : in out Budgets.Budget);
end Giflib_Tooling.Transition_Declarations;
