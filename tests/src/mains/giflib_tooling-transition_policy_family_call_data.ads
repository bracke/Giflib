private package Giflib_Tooling.Transition_Policy_Family_Call_Data is
   procedure Visit
     (Process : not null access procedure
        (Unit_Prefix : String; Callee : String));
end Giflib_Tooling.Transition_Policy_Family_Call_Data;
