with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Owned_Objects is
   use type Ownership.Allocation_Status;
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
      if not Ownership.Matches (Object.Owner, Budget) then
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
         procedure Allocate is
         begin
            Object.Pointer := new Element_Type;
         end Allocate;
         procedure Perform is new Ownership.Reserve_And_Allocate (Allocate);
      begin
         Perform (Ticket, Fault, Maximum, Required, Outcome);
      end;
      if Outcome.Status = Ownership.Allocation_Ready then
         Ownership.Bind (Object.Owner, Budget);
      end if;
      return Outcome;
   end Ensure;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Released : Boolean;
   begin
      if Object.Pointer /= null then
         Released := Ownership.Release_Owned
           (Object.Owner, Budget, Allocation_Bytes);
         Free (Object.Pointer);
      else
         Released := Ownership.Release_Owned (Object.Owner, Budget, 0);
      end if;
      return Released;
   end Release;

   function Is_Allocated (Object : Handle) return Boolean is
     (Object.Pointer /= null);

   function Value (Object : in out Handle) return not null Element_Access is
     (Object.Pointer);
end Giflib.Internal.Owned_Objects;
