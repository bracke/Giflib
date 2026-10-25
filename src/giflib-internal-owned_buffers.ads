with Giflib.Internal.Ownership;
with Giflib.Internal.Owned_Arrays;
with Giflib.Streams;

package Giflib.Internal.Owned_Buffers is
   pragma Preelaborate;

   package Storage is new Owned_Arrays
     (Positive, Byte, Streams.Byte_Array, 0);
   type Handle is limited private;
   --  A successful Ensure binds the handle to Budget until Release.  The
   --  binding stores only the ledger identity; callers supply the ledger when
   --  releasing, so the handle never retains a potentially dangling access.

   function Ensure
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   with Pre => Required in 1 .. Byte_Count (Natural'Last);

   function Release
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   --  A foreign Budget returns False without changing Buffer. Cleanup can be
   --  retried with the owning ledger.

   function Is_Allocated (Buffer : Handle) return Boolean;
   function Is_Borrowed (Buffer : Handle) return Boolean;
   function Length (Buffer : Handle) return Byte_Count;
   procedure Query
     (Buffer : in out Handle;
      Process : not null access procedure (Value : Streams.Byte_Array))
     with Pre => Is_Allocated (Buffer) and then not Is_Borrowed (Buffer);
   procedure Update
     (Buffer : in out Handle;
      Process : not null access procedure
        (Value : in out Streams.Byte_Array))
     with Pre => Is_Allocated (Buffer) and then not Is_Borrowed (Buffer);
   procedure Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access procedure
        (Source_Value : Streams.Byte_Array;
         Target_Value : in out Streams.Byte_Array))
     with Pre => Is_Allocated (Source)
                 and then Is_Allocated (Target)
                 and then not Is_Borrowed (Source)
                 and then not Is_Borrowed (Target);

private
   type Handle is limited record
      Owner : Storage.Handle;
   end record;
end Giflib.Internal.Owned_Buffers;
