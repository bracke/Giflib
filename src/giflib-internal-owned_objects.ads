with Giflib.Internal.Ownership;
with System;

generic
   type Element_Type is limited private;
package Giflib.Internal.Owned_Objects is
   pragma Preelaborate;

   type Handle is limited private;
   --  A successful Ensure binds the handle to Budget until Release.  The
   --  binding stores only the ledger identity; callers supply the ledger when
   --  releasing, so the handle never retains a potentially dangling access.
   type Element_Access is access all Element_Type;

   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;

   function Is_Allocated (Object : Handle) return Boolean;
   function Allocation_Bytes return Byte_Count;
   function Value (Object : in out Handle) return Element_Access
     with Pre => Is_Allocated (Object);

private
   type Handle is limited record
      Pointer : Element_Access := null;
      Budget_Address : System.Address := System.Null_Address;
   end record;
end Giflib.Internal.Owned_Objects;
