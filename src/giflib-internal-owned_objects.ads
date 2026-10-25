with Giflib.Internal.Ownership;
with Giflib.Internal.Borrow_Guards;
with Giflib.Internal.Cleanup;

generic
   type Element_Type is limited private;
package Giflib.Internal.Owned_Objects is
   pragma Preelaborate;
   pragma Unevaluated_Use_Of_Old (Allow);

   type Handle is limited private;
   --  A successful Ensure binds the handle to Budget until Release.  The
   --  binding stores only the ledger identity; callers supply the ledger when
   --  releasing, so the handle never retains a potentially dangling access.
   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;

   function Is_Allocated (Object : Handle) return Boolean;
   function Is_Borrowed (Object : Handle) return Boolean;
   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome
     with Post =>
       (if Release'Result.Status = Cleanup.Cleanup_Complete
          or else Release'Result.Status = Cleanup.Cleanup_Accounting_Failed
        then not Is_Allocated (Object)
        elsif Release'Result.Status = Cleanup.Cleanup_Borrow_Conflict
          or else Release'Result.Status = Cleanup.Cleanup_Owner_Mismatch
        then Is_Allocated (Object) = Is_Allocated (Object)'Old);
   --  A foreign Budget reports Cleanup_Owner_Mismatch without changing Object,
   --  and an active borrow reports Cleanup_Borrow_Conflict. A same-ledger
   --  bookkeeping failure still frees and clears Object and is recorded by the
   --  ledger.

   function Allocation_Bytes return Byte_Count;
   procedure Query
     (Object : in out Handle;
      Process : not null access procedure (Value : Element_Type))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);
   procedure Update
     (Object : in out Handle;
      Process : not null access procedure (Value : in out Element_Type))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);

   generic
      type Result_Type is private;
   package Result_Operations is
      function Query
        (Object : in out Handle;
         Process : not null access function
           (Value : Element_Type) return Result_Type) return Result_Type
        with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);

      function Update
        (Object : in out Handle;
         Process : not null access function
           (Value : in out Element_Type) return Result_Type) return Result_Type
        with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);
   end Result_Operations;

private
   type Element_Access is access all Element_Type;
   type Handle is limited record
      Pointer : Element_Access := null;
      Owner : Ownership.Budget_Owner;
      Borrow : aliased Borrow_Guards.State;
   end record;
end Giflib.Internal.Owned_Objects;
