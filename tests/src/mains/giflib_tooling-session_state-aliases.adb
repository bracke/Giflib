with Giflib_Tooling.Session_State.Bindings;

package body Giflib_Tooling.Session_State.Aliases is
   package Bindings renames Giflib_Tooling.Session_State.Bindings;

   procedure Add_Implicit
     (Object : in out State;
      Name : String;
      Target : String;
      Budget : in out Budgets.Budget) is
   begin
      Bindings.Add_Implicit_Package_Binding (Object, Name, Target, Budget);
   end Add_Implicit;

end Giflib_Tooling.Session_State.Aliases;
