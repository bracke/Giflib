with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Suite_Source_Selection is
   type Profile_Kind is (All_Tests_Profile, Register_Tests_Profile);
   type Selected_Body (Found : Boolean := False) is record
      case Found is
         when True =>
            First : Positive;
            Body_First : Positive;
            Last : Positive;
         when False =>
            null;
      end case;
   end record;

   procedure Inspect_Body
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Name : String;
      Profile : Profile_Kind;
      Process : not null access procedure
        (Selected : Selected_Body;
         Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
         Ranges :
           Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector));
end Giflib_Tooling.Suite_Source_Selection;
