with Giflib.Internal.Ownership;
with Giflib.Streams;
with System;

package Giflib.Internal.Owned_Buffers is
   pragma Preelaborate;

   type Byte_Array_Access is access all Streams.Byte_Array;
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

   function Is_Allocated (Buffer : Handle) return Boolean;
   function Length (Buffer : Handle) return Byte_Count;
   function Value
     (Buffer : in out Handle) return not null Byte_Array_Access
   with Pre => Is_Allocated (Buffer);

private
   type Handle is limited record
      Pointer : Byte_Array_Access := null;
      Budget_Address : System.Address := System.Null_Address;
   end record;
end Giflib.Internal.Owned_Buffers;
