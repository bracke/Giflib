with Giflib_Tooling.Transition_Policy_Index.Builders;

package body Giflib_Tooling.Transition_Policy is
   package Indexing renames Giflib_Tooling.Transition_Policy_Index;
   package Builders renames Giflib_Tooling.Transition_Policy_Index.Builders;
   use Ada.Strings.Unbounded;
   function Load return Policy is
      Result : Policy;
      Duplicate : Builders.Duplicate_Kind;
   begin
      Builders.Build (Result.Index, Duplicate);
      case Duplicate is
         when Builders.No_Duplicate =>
            null;
         when Builders.Duplicate_Global_Call =>
            Result.Error := To_Unbounded_String
              ("duplicate global transition call policy");
         when Builders.Duplicate_Family_Call =>
            Result.Error := To_Unbounded_String
              ("duplicate family transition call policy");
         when Builders.Duplicate_Alias =>
            Result.Error := To_Unbounded_String
              ("duplicate reviewed transition alias policy");
      end case;
      return Result;
   end Load;

   function Validation_Error (Object : Policy) return String is
     (To_String (Object.Error));

   function Is_Trusted_Qualifier
     (Object : Policy; Name : String) return Boolean is
     (Length (Object.Error) = 0
      and then Indexing.Is_Trusted_Qualifier (Object.Index, Name));

   function Is_Allowed_Call
     (Object : Policy; Callee : String; Unit_Name : String) return Boolean is
     (Length (Object.Error) = 0
      and then Indexing.Is_Allowed_Call (Object.Index, Callee, Unit_Name));

   function Is_Global_Allowed_Call
     (Object : Policy; Callee : String) return Boolean is
     (Length (Object.Error) = 0
      and then Indexing.Is_Global_Allowed_Call (Object.Index, Callee));

   function Allowed_Family
     (Object : Policy; Callee : String; Unit_Name : String)
      return Family_Match is
     (if Length (Object.Error) = 0
      then Indexing.Allowed_Family (Object.Index, Callee, Unit_Name)
      else (Found => False));

   function Is_Reviewed_Alias
     (Object : Policy;
      Unit_Name : String;
      Alias_Name : String;
      Target : String) return Boolean is
     (Length (Object.Error) = 0
        and then Indexing.Is_Reviewed_Alias
          (Object.Index, Unit_Name, Alias_Name, Target));

end Giflib_Tooling.Transition_Policy;
