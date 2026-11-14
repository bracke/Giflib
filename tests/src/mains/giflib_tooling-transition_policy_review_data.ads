private package Giflib_Tooling.Transition_Policy_Review_Data is
   procedure Visit_Reviewed_Aliases
     (Process : not null access procedure
        (Unit_Name : String; Alias_Name : String; Target : String));
end Giflib_Tooling.Transition_Policy_Review_Data;
