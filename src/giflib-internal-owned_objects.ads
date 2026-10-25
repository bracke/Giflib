with Giflib.Internal.Ownership;

generic
   type Element_Type is limited private;
package Giflib.Internal.Owned_Objects is
   pragma Preelaborate;

   type Handle is limited private;
   --  A successful Ensure binds the handle to Budget until Release.  The
   --  binding stores only the ledger identity; callers supply the ledger when
   --  releasing, so the handle never retains a potentially dangling access.
   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   --  A foreign Budget returns False without changing Object, so cleanup can
   --  be retried with the owning ledger. A same-ledger bookkeeping failure
   --  still frees and clears Object and is recorded by the ledger.

   function Is_Allocated (Object : Handle) return Boolean;
   function Is_Borrowed (Object : Handle) return Boolean;
   function Allocation_Bytes return Byte_Count;
   procedure Query
     (Object : in out Handle;
      Process : not null access procedure (Value : Element_Type))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);
   procedure Update
     (Object : in out Handle;
      Process : not null access procedure (Value : in out Element_Type))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);

private
   type Element_Access is access all Element_Type;
   type Handle is limited record
      Pointer : Element_Access := null;
      Owner : Ownership.Budget_Owner;
      Borrowed : Boolean := False;
   end record;
end Giflib.Internal.Owned_Objects;
