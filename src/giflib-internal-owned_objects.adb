with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Owned_Objects is
   use type Ownership.Allocation_Status;
   use type System.Address;
   procedure Free is new Ada.Unchecked_Deallocation
     (Element_Type, Element_Access);

   function Allocation_Bytes return Byte_Count is
     (Ownership.Storage_Bytes (Element_Type'Object_Size));

   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
      Required : constant Byte_Count := Allocation_Bytes;
      Outcome : Ownership.Allocation_Outcome;

   begin
      if Object.Budget_Address /= System.Null_Address
        and then Object.Budget_Address /= Budget'Address
      then
         return
           (Status => Ownership.Allocation_Owner_Error,
            Attempted => Ownership.Used (Budget));
      end if;
      if Object.Pointer /= null then
         return (Status => Ownership.Allocation_Ready,
                 Attempted => Ownership.Used (Budget));
      end if;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Outcome := Ownership.Reserve
           (Ticket, Fault, Maximum, Required);
         if Outcome.Status = Ownership.Allocation_Ready then
            begin
               Object.Pointer := new Element_Type;
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Outcome);
            end;
         end if;
      end;
      if Outcome.Status = Ownership.Allocation_Ready then
         Object.Budget_Address := Budget'Address;
      end if;
      return Outcome;
   end Ensure;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
   begin
      if Object.Budget_Address /= System.Null_Address
        and then Object.Budget_Address /= Budget'Address
      then
         return False;
      end if;
      if Object.Pointer /= null then
         Ownership.Release (Budget, Allocation_Bytes);
         Free (Object.Pointer);
         Object.Budget_Address := System.Null_Address;
      end if;
      return True;
   end Release;

   function Is_Allocated (Object : Handle) return Boolean is
     (Object.Pointer /= null);

   function Value (Object : in out Handle) return Element_Access is
     (Object.Pointer);
end Giflib.Internal.Owned_Objects;
