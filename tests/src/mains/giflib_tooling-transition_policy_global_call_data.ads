private package Giflib_Tooling.Transition_Policy_Global_Call_Data is
   function Session_Prefix return String;
   procedure Visit
     (Process : not null access procedure (Callee : String));
end Giflib_Tooling.Transition_Policy_Global_Call_Data;
