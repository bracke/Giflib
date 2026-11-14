with Ada.Strings.Unbounded;

with Giflib_Tooling.Transition_Policy_Index;

private package Giflib_Tooling.Transition_Policy is
   type Policy is private;
   function Load return Policy;
   function Validation_Error (Object : Policy) return String;
   function Is_Trusted_Qualifier
     (Object : Policy; Name : String) return Boolean;
   function Is_Allowed_Call
     (Object : Policy; Callee : String; Unit_Name : String) return Boolean;
   function Is_Global_Allowed_Call
     (Object : Policy; Callee : String) return Boolean;
   subtype Family_Match is
     Giflib_Tooling.Transition_Policy_Index.Family_Match;
   function Allowed_Family
     (Object : Policy; Callee : String; Unit_Name : String)
      return Family_Match;
   function Is_Reviewed_Alias
     (Object : Policy;
      Unit_Name : String;
      Alias_Name : String;
      Target : String) return Boolean;
private
   type Policy is record
      Index : Giflib_Tooling.Transition_Policy_Index.Index;
      Error : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Giflib_Tooling.Transition_Policy;
