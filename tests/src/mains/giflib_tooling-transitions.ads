with Giflib_Tooling.Source_Model;

package Giflib_Tooling.Transitions is
   function Violation
     (Statement : Source_Model.Token_Vectors.Vector;
      Protected_Fields : Source_Model.Name_Vectors.Vector;
      Session_Names : Source_Model.Name_Vectors.Vector;
      Unit_Name : String := "") return Boolean;
   procedure Validate (Root : String);
end Giflib_Tooling.Transitions;
