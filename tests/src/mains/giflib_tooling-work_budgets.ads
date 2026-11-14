with Ada.Finalization;

private package Giflib_Tooling.Work_Budgets is
   Maximum_Work : constant := 10_000_000;
   Maximum_Depth : constant := 256;

   type Budget (Work_Limit : Natural := Maximum_Work) is tagged limited private;
   type Depth_Guard is limited private;

   Work_Limit_Exceeded : exception;

   procedure Charge
     (Object : in out Budget; Amount : Natural := 1);
   procedure Charge_Scan
     (Object : in out Budget; Item_Count : Natural);
   function Used (Object : Budget) return Natural;
   function Child
     (Object : in out Budget'Class;
      Work_Limit : Natural) return Budget;
   function Enter (Object : in out Budget'Class) return Depth_Guard;
private
   type Budget_State (Work_Limit : Natural);
   type Budget_State_Access is access Budget_State;
   type Budget_State (Work_Limit : Natural) is record
      Work_Remaining : Natural := Work_Limit;
      Depth : Natural := 0;
      References : Positive := 1;
      Parent : Budget_State_Access := null;
   end record;
   type Budget (Work_Limit : Natural := Maximum_Work) is
     new Ada.Finalization.Limited_Controlled with record
      Data : Budget_State_Access := null;
   end record;
   overriding procedure Initialize (Object : in out Budget);
   overriding procedure Finalize (Object : in out Budget);
   function Can_Charge
     (Object : Budget; Amount : Natural := 1) return Boolean;
   function Can_Enter (Object : Budget) return Boolean;
   type Depth_Guard is new Ada.Finalization.Limited_Controlled with record
      Owner : Budget_State_Access := null;
   end record;
   overriding procedure Finalize (Object : in out Depth_Guard);
end Giflib_Tooling.Work_Budgets;
