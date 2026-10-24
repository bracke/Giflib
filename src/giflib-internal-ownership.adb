with System;
with Giflib.Internal.Budget_Arithmetic;

package body Giflib.Internal.Ownership is
   procedure Check_Allocation (State : in out Fault_State) is
      Result : constant Ownership_Arithmetic.Check_Result :=
        Ownership_Arithmetic.Check (State.Value);
   begin
      State.Value := Result.State;
      if Result.Raise_Error then
         raise Storage_Error;
      end if;
   end Check_Allocation;

   function Reserve
     (Ticket : in out Reservation;
      Fault : in out Fault_State;
      Maximum : Byte_Count;
      Amount : Byte_Count) return Allocation_Outcome
   is
      Attempted : constant Byte_Count :=
        Attempted_Total (Ticket.Budget.all, Amount);
      Reserved : Boolean;
   begin
      pragma Assert (not Ticket.Active);
      Try_Reserve (Ticket.Budget.all, Maximum, Amount, Reserved);
      if not Reserved then
         return (Status => Allocation_Limit, Attempted => Attempted);
      end if;
      Ticket.Amount := Amount;
      Ticket.Active := True;
      begin
         Check_Allocation (Fault);
      exception
         when Storage_Error =>
            Release (Ticket.Budget.all, Amount);
            Ticket.Active := False;
            return (Status => Allocation_Storage_Error,
                    Attempted => Attempted);
      end;
      return
        (Status => Allocation_Ready,
         Attempted => Used (Ticket.Budget.all));
   end Reserve;

   procedure Commit (Ticket : in out Reservation) is
   begin
      pragma Assert (Ticket.Active);
      Ticket.Active := False;
   end Commit;

   procedure Cancel
     (Ticket : in out Reservation;
      Outcome : in out Allocation_Outcome)
   is
   begin
      if Ticket.Active then
         Release (Ticket.Budget.all, Ticket.Amount);
         Ticket.Active := False;
      end if;
      Outcome.Status := Allocation_Storage_Error;
   end Cancel;

   overriding procedure Finalize (Ticket : in out Reservation) is
   begin
      if Ticket.Active then
         Release (Ticket.Budget.all, Ticket.Amount);
         Ticket.Active := False;
      end if;
   end Finalize;

   function Storage_Bytes (Size_In_Bits : Natural) return Byte_Count is
     (Byte_Count
        (Size_In_Bits / System.Storage_Unit
         + (if Size_In_Bits mod System.Storage_Unit = 0 then 0 else 1)));

   function Used (Budget : Byte_Budget) return Byte_Count is
     (Budget.Used_Bytes);

   function Attempted_Total
     (Budget : Byte_Budget;
      Amount : Byte_Count) return Byte_Count
   is
     (Budget_Arithmetic.Charge
        (Budget.Used_Bytes, Byte_Count'Last, Amount).Attempted);

   procedure Try_Reserve
     (Budget : in out Byte_Budget;
      Maximum : Byte_Count;
      Amount : Byte_Count;
      Accepted : out Boolean)
   is
      Charge : constant Budget_Arithmetic.Charge_Result :=
        Budget_Arithmetic.Charge (Budget.Used_Bytes, Maximum, Amount);
   begin
      Accepted := Charge.Accepted;
      if Accepted then
         Budget.Used_Bytes := Charge.Total;
      end if;
   end Try_Reserve;

   procedure Release
     (Budget : in out Byte_Budget;
      Amount : Byte_Count)
   is
   begin
      Budget.Used_Bytes := Budget.Used_Bytes - Amount;
   end Release;

end Giflib.Internal.Ownership;
