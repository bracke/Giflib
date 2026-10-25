with Giflib.Internal.Budget_Arithmetic;
with System;

package body Giflib.Internal.Ownership is
   protected Identity_Generator is
      procedure Take (Value : out Budget_Identity);
   private
      Next : Budget_Identity := 1;
   end Identity_Generator;

   protected body Identity_Generator is
      procedure Take (Value : out Budget_Identity) is
      begin
         Value := Next;
         Next := Next + 1;
         if Next = 0 then
            Next := 1;
         end if;
      end Take;
   end Identity_Generator;

   function Fresh_Identity return Budget_Identity is
      Result : Budget_Identity;
   begin
      Identity_Generator.Take (Result);
      return Result;
   end Fresh_Identity;

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
      if not Healthy (Ticket.Budget.all) then
         return
           (Status => Allocation_Owner_Error,
            Attempted => Attempted);
      end if;
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
            if not Release (Ticket.Budget.all, Amount) then
               Ticket.Active := False;
               return
                 (Status => Allocation_Owner_Error,
                  Attempted => Attempted);
            end if;
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

   procedure Reserve_And_Allocate
     (Ticket : in out Reservation;
      Fault : in out Fault_State;
      Maximum : Byte_Count;
      Amount : Byte_Count;
      Outcome : out Allocation_Outcome)
   is
   begin
      Outcome := Reserve (Ticket, Fault, Maximum, Amount);
      if Outcome.Status = Allocation_Ready then
         begin
            Allocate;
            Commit (Ticket);
         exception
            when Storage_Error =>
               Cancel (Ticket, Outcome);
         end;
      end if;
   end Reserve_And_Allocate;

   procedure Cancel
     (Ticket : in out Reservation;
      Outcome : in out Allocation_Outcome)
   is
   begin
      if Ticket.Active then
         if not Release (Ticket.Budget.all, Ticket.Amount) then
            Outcome.Status := Allocation_Owner_Error;
            Ticket.Active := False;
            return;
         end if;
         Ticket.Active := False;
      end if;
      Outcome.Status := Allocation_Storage_Error;
   end Cancel;

   overriding procedure Finalize (Ticket : in out Reservation) is
   begin
      if Ticket.Active then
         --  Release records a sticky ledger fault when rollback is impossible;
         --  the owning resource set observes it during explicit cleanup.
         Rollback (Ticket.Budget.all, Ticket.Amount);
         Ticket.Active := False;
      end if;
   end Finalize;

   function Storage_Bytes (Size_In_Bits : Natural) return Byte_Count is
     (Byte_Count
        (Size_In_Bits / System.Storage_Unit
         + (if Size_In_Bits mod System.Storage_Unit = 0 then 0 else 1)));

   function Used (Budget : Byte_Budget) return Byte_Count is
     (Budget.Used_Bytes);

   function Healthy (Budget : Byte_Budget) return Boolean is
     (not Budget.Corrupted);

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
      if Budget.Corrupted then
         Accepted := False;
         return;
      end if;
      Accepted := Charge.Accepted;
      if Accepted then
         Budget.Used_Bytes := Charge.Total;
      end if;
   end Try_Reserve;

   function Release
     (Budget : in out Byte_Budget;
      Amount : Byte_Count) return Boolean
   is
   begin
      if Amount > Budget.Used_Bytes then
         Budget.Corrupted := True;
         return False;
      end if;
      Budget.Used_Bytes := Budget.Used_Bytes - Amount;
      return True;
   end Release;

   procedure Rollback
     (Budget : in out Byte_Budget;
      Amount : Byte_Count)
   is
   begin
      if Amount > Budget.Used_Bytes then
         Budget.Corrupted := True;
      else
         Budget.Used_Bytes := Budget.Used_Bytes - Amount;
      end if;
   end Rollback;

   function Matches
     (Owner : Budget_Owner;
      Budget : aliased Byte_Budget) return Boolean
   is
     (Owner.Identity = 0
      or else Owner.Identity = Budget.Identity);

   function Is_Bound (Owner : Budget_Owner) return Boolean is
     (Owner.Identity /= 0);

   procedure Bind
     (Owner : out Budget_Owner;
      Budget : aliased Byte_Budget)
   is
   begin
      Owner.Identity := Budget.Identity;
   end Bind;

   function Release_Owned
     (Owner : in out Budget_Owner;
      Budget : aliased in out Byte_Budget;
      Amount : Byte_Count) return Boolean
   is
      Same_Owner : constant Boolean := Matches (Owner, Budget);
      Released : constant Boolean :=
        (if Same_Owner then Release (Budget, Amount) else False);
   begin
      Owner.Identity := 0;
      return Released;
   end Release_Owned;

   procedure Attempt_Release (Failed : in out Boolean) is
   begin
      if not Release_Operation then
         Failed := True;
      end if;
   exception
      when others =>
         Failed := True;
   end Attempt_Release;

end Giflib.Internal.Ownership;
