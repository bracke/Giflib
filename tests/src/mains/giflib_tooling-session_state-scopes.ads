package Giflib_Tooling.Session_State.Scopes is
   procedure Push
     (Object : in out State; Kind : Scope_Kind; End_Name : String := "");
   procedure Pop (Object : in out State; Budget : in out Budgets.Budget);
   function Is_Empty (Object : State) return Boolean;
   function Depth (Object : State) return Natural;
   function Top_Is (Object : State; Kind : Scope_Kind) return Boolean;
   function Top_End_Name (Object : State) return String;
   function Is_Context_Level (Object : State) return Boolean;
   function Is_Context_Component_Level (Object : State) return Boolean;
end Giflib_Tooling.Session_State.Scopes;
