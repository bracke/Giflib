private package Giflib_Tooling.Transition_Policy_Call_Data is
   function Session_Prefix return String;

   procedure Visit_Global_Calls
     (Process : not null access procedure (Callee : String));

   procedure Visit_Family_Calls
     (Process : not null access procedure
        (Unit_Prefix : String; Callee : String));

end Giflib_Tooling.Transition_Policy_Call_Data;
