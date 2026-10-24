with Giflib.Internal.Ownership_Arithmetic;
with Ada.Finalization;

package Giflib.Internal.Ownership is
   pragma Preelaborate;

   type Fault_State is limited private;
   type Byte_Budget is limited private;
   type Reservation (Budget : not null access Byte_Budget) is limited private;

   type Allocation_Status is
     (Allocation_Ready,
      Allocation_Limit,
      Allocation_Storage_Error,
      Allocation_Owner_Error);
   type Allocation_Outcome is record
      Status : Allocation_Status := Allocation_Ready;
      Attempted : Byte_Count := 0;
   end record;

   --  Production objects own independent, normally-disabled allocation state.
   --  Test-only child packages can arm that state without any global registry.
   procedure Check_Allocation (State : in out Fault_State);

   function Reserve
     (Ticket : in out Reservation;
      Fault : in out Fault_State;
      Maximum : Byte_Count;
      Amount : Byte_Count) return Allocation_Outcome;
   --  Reserve the caller's type-derived logical storage charge and apply fault
   --  injection.  The resource owner performs the typed allocation next and
   --  commits it on success.  An uncommitted ticket rolls its charge back
   --  automatically; Cancel also records a translated Storage_Error outcome.

   procedure Commit (Ticket : in out Reservation);

   procedure Cancel
     (Ticket : in out Reservation;
      Outcome : in out Allocation_Outcome)
     with Pre =>
       Outcome.Status = Allocation_Ready,
       Post => Outcome.Status = Allocation_Storage_Error;

   function Storage_Bytes (Size_In_Bits : Natural) return Byte_Count;
   function Used (Budget : Byte_Budget) return Byte_Count;
   function Attempted_Total
     (Budget : Byte_Budget;
      Amount : Byte_Count) return Byte_Count;
   procedure Try_Reserve
     (Budget : in out Byte_Budget;
      Maximum : Byte_Count;
      Amount : Byte_Count;
      Accepted : out Boolean);
   procedure Release
     (Budget : in out Byte_Budget;
      Amount : Byte_Count)
     with Pre => Amount <= Used (Budget);
private
   type Fault_State is limited record
      Value : Ownership_Arithmetic.Injection_State :=
        Ownership_Arithmetic.Disabled;
   end record;

   type Byte_Budget is limited record
      Used_Bytes : Byte_Count := 0;
   end record;

   type Reservation (Budget : not null access Byte_Budget) is
     new Ada.Finalization.Limited_Controlled with record
      Amount : Byte_Count := 0;
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (Ticket : in out Reservation);
end Giflib.Internal.Ownership;
