with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Owned_Element_Vectors is
   use type Ownership.Allocation_Status;

   procedure Free is new Ada.Unchecked_Deallocation
     (Element_Type, Element_Access);

   function Element_Charge return Byte_Count is
     (Ownership.Storage_Bytes (Element_Type'Object_Size));

   function Append_New
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count;
      Index : out Positive) return Ownership.Allocation_Outcome
   is
      Allocation : Ownership.Allocation_Outcome;
      Value : Element_Access;
   begin
      Index := 1;
      if Borrow_Guards.Is_Active (Object.Borrow) then
         return (Status => Ownership.Allocation_Borrow_Error,
                 Attempted => Ownership.Used (Budget));
      end if;
      Allocation := Indexes.Ensure_Append
        (Object.Entries, Budget, Fault, Maximum);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation;
      end if;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
         procedure Allocate is
         begin
            Value := new Element_Type;
         end Allocate;
         procedure Perform is new Ownership.Reserve_And_Allocate (Allocate);
      begin
         Perform (Ticket, Fault, Maximum, Element_Charge, Allocation);
      end;
      if Allocation.Status = Ownership.Allocation_Ready then
         Indexes.Append (Object.Entries, Value);
         Index := Indexes.Length (Object.Entries);
      end if;
      return Allocation;
   end Append_New;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Released : Boolean := True;
      Step : Boolean;
      Value : Element_Access;
   begin
      if Borrow_Guards.Is_Active (Object.Borrow)
        or else not Indexes.Matches (Object.Entries, Budget)
      then
         return False;
      end if;
      for Index in 1 .. Indexes.Length (Object.Entries) loop
         Value := Indexes.Element (Object.Entries, Index);
         Step := Release_Contents (Value.all, Budget);
         Released := Step and Released;
         Step := Ownership.Release (Budget, Element_Charge);
         Released := Step and Released;
         Free (Value);
      end loop;
      Step := Indexes.Release (Object.Entries, Budget);
      return Step and Released;
   end Release;

   function Length (Object : Handle) return Natural is
     (Indexes.Length (Object.Entries));

   function Is_Allocated (Object : Handle) return Boolean is
     (Indexes.Is_Allocated (Object.Entries));

   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean
   is (Indexes.Matches (Object.Entries, Budget));

   function Element
     (Object : Handle;
      Index : Positive) return not null access constant Element_Type
   is (Indexes.Element (Object.Entries, Index));

   procedure Update
     (Object : in out Handle;
      Index : Positive;
      Process : not null access procedure (Value : in out Element_Type))
   is
      Lease : Borrow_Guards.Guard (Object.Borrow'Access);
      pragma Unreferenced (Lease);
      Value : constant Element_Access := Indexes.Element (Object.Entries, Index);
   begin
      Process (Value.all);
   end Update;
end Giflib.Internal.Owned_Element_Vectors;
