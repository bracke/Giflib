with Giflib_Tooling.Transition_Policy_Global_Call_Data;
with Giflib_Tooling.Transition_Policy_Family_Call_Data;

package body Giflib_Tooling.Transition_Policy_Call_Data is
   package Global renames
     Giflib_Tooling.Transition_Policy_Global_Call_Data;
   package Family renames
     Giflib_Tooling.Transition_Policy_Family_Call_Data;

   function Session_Prefix return String is (Global.Session_Prefix);

   procedure Visit_Global_Calls
     (Process : not null access procedure (Callee : String)) is
   begin
      Global.Visit (Process);
   end Visit_Global_Calls;

   procedure Visit_Family_Calls
     (Process : not null access procedure
        (Unit_Prefix : String; Callee : String)) is
   begin
      Family.Visit (Process);
   end Visit_Family_Calls;

end Giflib_Tooling.Transition_Policy_Call_Data;
