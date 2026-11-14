with Ada.Unchecked_Deallocation;

package body Giflib_Tooling.Work_Budgets is
   procedure Free is new Ada.Unchecked_Deallocation
     (Budget_State, Budget_State_Access);

   procedure Release (Data : in out Budget_State_Access) is
   begin
      if Data = null then
         return;
      elsif Data.References = 1 then
         declare
            Parent : Budget_State_Access := Data.Parent;
         begin
            Free (Data);
            Release (Parent);
         end;
      else
         Data.References := Data.References - 1;
         Data := null;
      end if;
   end Release;

   overriding procedure Initialize (Object : in out Budget) is
   begin
      Object.Data := new Budget_State (Object.Work_Limit);
   end Initialize;

   overriding procedure Finalize (Object : in out Budget) is
   begin
      Release (Object.Data);
   end Finalize;

   function State_Can_Charge
     (Data : Budget_State_Access; Amount : Natural) return Boolean is
     (Data /= null
      and then Data.Work_Remaining >= Amount
      and then
        (Data.Parent = null or else State_Can_Charge (Data.Parent, Amount)));

   function Can_Charge
     (Object : Budget; Amount : Natural := 1) return Boolean is
     (State_Can_Charge (Object.Data, Amount));

   procedure Apply_Charge
     (Data : Budget_State_Access; Amount : Natural) is
   begin
      Data.Work_Remaining := Data.Work_Remaining - Amount;
      if Data.Parent /= null then
         Apply_Charge (Data.Parent, Amount);
      end if;
   end Apply_Charge;

   function Can_Enter (Object : Budget) return Boolean is
     (Object.Data.Depth < Maximum_Depth);

   procedure Charge
     (Object : in out Budget; Amount : Natural := 1) is
   begin
      if not Can_Charge (Object, Amount) then
         raise Work_Limit_Exceeded with "tooling work budget exhausted";
      end if;
      Apply_Charge (Object.Data, Amount);
   end Charge;

   procedure Charge_Scan
     (Object : in out Budget; Item_Count : Natural) is
   begin
      Charge (Object, Item_Count);
   end Charge_Scan;

   function Used (Object : Budget) return Natural is
     (Object.Work_Limit - Object.Data.Work_Remaining);

   function Child
     (Object : in out Budget'Class;
      Work_Limit : Natural) return Budget is
   begin
      return Result : Budget (Work_Limit) do
         Result.Data.Parent := Object.Data;
         Object.Data.References := Object.Data.References + 1;
      end return;
   end Child;

   function Enter (Object : in out Budget'Class) return Depth_Guard is
   begin
      Charge (Object);
      if not Can_Enter (Object) then
         raise Work_Limit_Exceeded with "tooling depth budget exhausted";
      end if;
      Object.Data.Depth := Object.Data.Depth + 1;
      Object.Data.References := Object.Data.References + 1;
      return Result : Depth_Guard do
         Result.Owner := Object.Data;
      end return;
   end Enter;

   overriding procedure Finalize (Object : in out Depth_Guard) is
   begin
      if Object.Owner /= null then
         Object.Owner.Depth := Object.Owner.Depth - 1;
         Release (Object.Owner);
      end if;
   end Finalize;
end Giflib_Tooling.Work_Budgets;
