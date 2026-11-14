package body Giflib_Tooling.Storage_Budgets is
   procedure Charge (Object : in out Budget; Amount : Natural := 1) is
   begin
      if not Object.Valid then
         raise Program_Error with "storage budget accounting is invalid";
      elsif Amount > Object.Limit - Object.Retained - Object.Provisional then
         raise Limit_Exceeded;
      end if;
      Object.Retained := Object.Retained + Amount;
   end Charge;

   procedure Release_Retained
     (Object : in out Budget; Amount : Natural := 1) is
   begin
      if not Object.Valid then
         raise Program_Error with "storage budget accounting is invalid";
      elsif Amount > Object.Retained then
         raise Program_Error with "storage release exceeds retained charge";
      end if;
      Object.Retained := Object.Retained - Amount;
   end Release_Retained;

   function Used (Object : Budget) return Natural is
   begin
      if not Object.Valid then
         raise Program_Error with "storage budget accounting is invalid";
      end if;
      return Object.Retained + Object.Provisional;
   end Used;

   function Start (Object : aliased in out Budget) return Transaction is
   begin
      if not Object.Valid then
         raise Program_Error with "storage budget accounting is invalid";
      elsif Object.Next_Transaction_Id = Natural'Last then
         raise Program_Error with "storage transaction identity exhausted";
      end if;
      Object.Next_Transaction_Id := Object.Next_Transaction_Id + 1;
      return Result : Transaction (Object'Access) do
         Result.Id := Object.Next_Transaction_Id;
      end return;
   end Start;

   procedure Charge (Object : in out Transaction; Amount : Natural := 1) is
   begin
      if not Object.Active then
         raise Program_Error with "storage transaction is already committed";
      end if;
      if not Object.Owner.Valid then
         raise Program_Error with "storage budget accounting is invalid";
      elsif Amount > Object.Owner.Limit - Object.Owner.Retained -
        Object.Owner.Provisional
      then
         raise Limit_Exceeded;
      end if;
      Object.Owner.Provisional := Object.Owner.Provisional + Amount;
      Object.Amount := Object.Amount + Amount;
   end Charge;

   procedure Commit (Object : in out Transaction) is
   begin
      if not Object.Active then
         raise Program_Error with "storage transaction is already committed";
      end if;
      if Object.Amount > Object.Owner.Provisional then
         raise Program_Error with "storage transaction accounting mismatch";
      end if;
      Object.Owner.Provisional := Object.Owner.Provisional - Object.Amount;
      Object.Owner.Retained := Object.Owner.Retained + Object.Amount;
      Object.Amount := 0;
      Object.Active := False;
   end Commit;

   procedure Transfer
     (Object : in out Transaction; Target : in out Transaction) is
   begin
      if not Object.Active or else not Target.Active then
         raise Program_Error with "storage transaction is already committed";
      elsif Object.Id = Target.Id then
         raise Program_Error with "storage transaction cannot transfer itself";
      elsif Object.Owner /= Target.Owner then
         raise Program_Error with "storage transactions have different owners";
      end if;
      Target.Amount := Target.Amount + Object.Amount;
      Object.Amount := 0;
      Object.Active := False;
   end Transfer;

   overriding procedure Finalize (Object : in out Transaction) is
   begin
      if Object.Active then
         if Object.Amount <= Object.Owner.Provisional then
            Object.Owner.Provisional :=
              Object.Owner.Provisional - Object.Amount;
         else
            Object.Owner.Valid := False;
         end if;
         Object.Amount := 0;
         Object.Active := False;
      end if;
   end Finalize;
end Giflib_Tooling.Storage_Budgets;
