with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Units;

private package Giflib_Tooling.Transition_Index.Context_Building is
   function Inherited_Context
     (Object : in out Source_Index;
      Prefix : String;
      Target_Type : Giflib_Tooling.Session_Identity.Target;
      Target_Name : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause)
      return Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
end Giflib_Tooling.Transition_Index.Context_Building;
