with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Units;

private package Giflib_Tooling.Transition_Index.Ancestry is
   function Resolve
     (Object : in out Source_Index;
      Prefix : String;
      Target_Name : String;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
end Giflib_Tooling.Transition_Index.Ancestry;
