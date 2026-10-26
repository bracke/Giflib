with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Testing.Owned_Element_Vectors is
   use type Ownership.Allocation_Status;
   use type Cleanup.Cleanup_Status;

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
      if Borrow_Guards.Is_Active (Object.Borrow)
        or else Object.Cleanup_Active
      then
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
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome
   is
      Released : Cleanup.Cleanup_Outcome := Cleanup.Success;
      Step : Cleanup.Cleanup_Outcome;
      Index_Cleanup : Cleanup.Cleanup_Outcome;
      Value : Element_Access;
   begin
      if Borrow_Guards.Is_Active (Object.Borrow)
      then
         return (Status => Cleanup.Cleanup_Borrow_Conflict);
      elsif not Indexes.Matches (Object.Entries, Budget) then
         return (Status => Cleanup.Cleanup_Owner_Mismatch);
      end if;
      if not Object.Cleanup_Active then
         for Index in 1 .. Indexes.Length (Object.Entries) loop
            Value := Indexes.Element (Object.Entries, Index);
            begin
               declare
                  Lease : Borrow_Guards.Guard (Object.Borrow'Access);
                  pragma Unreferenced (Lease);
               begin
                  if not Contents_Releasable (Value.all, Budget) then
                     return (Status => Cleanup.Cleanup_Preflight_Refused);
                  end if;
               end;
            exception
               when others =>
                  return (Status => Cleanup.Cleanup_Callback_Failed);
            end;
         end loop;
         Object.Cleanup_Active := True;
         Object.Cleanup_Position := 0;
         Object.Cleanup_Status := Cleanup.Cleanup_Complete;
      end if;
      --  Consume every nested resource before freeing any outer element.
      --  Completed callbacks are checkpointed, so an exceptional callback is
      --  the only callback that may be retried.
      if Object.Cleanup_Position < Indexes.Length (Object.Entries) then
         for Index in Object.Cleanup_Position + 1
           .. Indexes.Length (Object.Entries)
         loop
            Value := Indexes.Element (Object.Entries, Index);
            begin
               declare
                  Lease : Borrow_Guards.Guard (Object.Borrow'Access);
                  pragma Unreferenced (Lease);
               begin
                  Step := Release_Contents (Value.all, Budget);
               end;
            exception
               when others =>
                  return (Status => Cleanup.Cleanup_Callback_Failed);
            end;
            if not Cleanup.Succeeded (Step)
              and then Object.Cleanup_Status = Cleanup.Cleanup_Complete
            then
               Object.Cleanup_Status := Step.Status;
            end if;
            Object.Cleanup_Position := Index;
         end loop;
      end if;
      Released := (Status => Object.Cleanup_Status);
      for Index in 1 .. Indexes.Length (Object.Entries) loop
         Value := Indexes.Element (Object.Entries, Index);
         if not Ownership.Release (Budget, Element_Charge)
           and then Cleanup.Succeeded (Released)
         then
            Released := (Status => Cleanup.Cleanup_Accounting_Failed);
         end if;
         Free (Value);
      end loop;
      Index_Cleanup := Indexes.Release (Object.Entries, Budget);
      if not Cleanup.Succeeded (Index_Cleanup)
        and then Cleanup.Succeeded (Released)
      then
         Released := Index_Cleanup;
      end if;
      Object.Cleanup_Active := False;
      Object.Cleanup_Position := 0;
      Object.Cleanup_Status := Cleanup.Cleanup_Complete;
      return Released;
   end Release;

   function Length (Object : Handle) return Natural is
     (Indexes.Length (Object.Entries));

   function Is_Allocated (Object : Handle) return Boolean is
     (Indexes.Is_Allocated (Object.Entries));

   function Is_Borrowed (Object : Handle) return Boolean is
     (Borrow_Guards.Is_Active (Object.Borrow));

   function Is_Cleanup_In_Progress (Object : Handle) return Boolean is
     (Object.Cleanup_Active);

   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean
   is (Indexes.Matches (Object.Entries, Budget));

   procedure Query
     (Object : in out Handle;
      Index : Positive;
      Process : not null access procedure (Value : Element_Type))
   is
      Lease : Borrow_Guards.Guard (Object.Borrow'Access);
      pragma Unreferenced (Lease);
      Value : constant Element_Access := Indexes.Element (Object.Entries, Index);
   begin
      Process (Value.all);
   end Query;

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
end Giflib.Internal.Testing.Owned_Element_Vectors;
