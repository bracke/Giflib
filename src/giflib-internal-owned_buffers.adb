with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Owned_Buffers is
   use type Ownership.Allocation_Status;
   use type System.Address;

   procedure Free is new Ada.Unchecked_Deallocation
     (Streams.Byte_Array, Byte_Array_Access);

   function Ensure
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
      Outcome : Ownership.Allocation_Outcome;

   begin
      if Buffer.Budget_Address /= System.Null_Address
        and then Buffer.Budget_Address /= Budget'Address
      then
         return
           (Status => Ownership.Allocation_Owner_Error,
            Attempted => Ownership.Used (Budget));
      end if;
      if Buffer.Pointer /= null
        and then Byte_Count (Buffer.Pointer'Length) >= Required
      then
         return (Status => Ownership.Allocation_Ready,
                 Attempted => Ownership.Used (Budget));
      end if;
      if not Release (Buffer, Budget) then
         return
           (Status => Ownership.Allocation_Owner_Error,
            Attempted => Ownership.Used (Budget));
      end if;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Outcome := Ownership.Reserve
           (Ticket, Fault, Maximum, Required);
         if Outcome.Status = Ownership.Allocation_Ready then
            begin
               Buffer.Pointer :=
                 new Streams.Byte_Array (1 .. Natural (Required));
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Outcome);
            end;
         end if;
      end;
      if Outcome.Status = Ownership.Allocation_Ready then
         Buffer.Budget_Address := Budget'Address;
      end if;
      return Outcome;
   end Ensure;

   function Release
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
   begin
      if Buffer.Budget_Address /= System.Null_Address
        and then Buffer.Budget_Address /= Budget'Address
      then
         return False;
      end if;
      if Buffer.Pointer /= null then
         Ownership.Release (Budget, Byte_Count (Buffer.Pointer'Length));
         Free (Buffer.Pointer);
         Buffer.Budget_Address := System.Null_Address;
      end if;
      return True;
   end Release;

   function Is_Allocated (Buffer : Handle) return Boolean is
     (Buffer.Pointer /= null);

   function Length (Buffer : Handle) return Byte_Count is
     (if Buffer.Pointer = null then 0 else Byte_Count (Buffer.Pointer'Length));

   function Value
     (Buffer : in out Handle) return not null Byte_Array_Access is
     (Buffer.Pointer);
end Giflib.Internal.Owned_Buffers;
