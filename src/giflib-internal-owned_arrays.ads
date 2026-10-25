with Giflib.Internal.Ownership;

generic
   type Index_Type is range <>;
   type Element_Type is private;
   type Element_Array is array (Index_Type range <>) of Element_Type;
   Default_Element : Element_Type;
package Giflib.Internal.Owned_Arrays is
   pragma Preelaborate;
   pragma Compile_Time_Error
     (Index_Type'Pos (Index_Type'First) < Integer'Pos (Integer'First)
      or else Index_Type'Pos (Index_Type'Last) > Integer'Pos (Integer'Last),
      "Owned_Arrays index type must fit in Integer");

   type Element_Array_Access is access all Element_Array;
   type Handle is limited private;

   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      First : Index_Type;
      Last : Index_Type;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Pre => First <= Last;
   --  Allocation and budget failure leave Object and its ledger charge
   --  unchanged. Existing contents need not be preserved after success when
   --  the bounds grow; use Grow when a prefix must survive.

   function Grow
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      First : Index_Type;
      Last : Index_Type;
      Preserve : Natural;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Pre => First <= Last;
   --  Ensures the requested bounds without discarding the first Preserve
   --  elements. Every other capacity slot is initialized to Default_Element.
   --  Allocation and budget failure leave Object unchanged.

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   --  A foreign Budget returns False without changing Object, so cleanup can
   --  be retried with the owning ledger. A same-ledger bookkeeping failure
   --  still frees and clears Object and is recorded by the ledger.

   function Is_Allocated (Object : Handle) return Boolean;
   function Contains
     (Object : Handle;
      Index : Index_Type) return Boolean;
   --  Contains describes allocated capacity. Every contained slot always has a
   --  defined value; higher-level collections may impose a smaller logical
   --  length before exposing their contents.
   function Length (Object : Handle) return Natural;
   function Allocation_Bytes (Length : Natural) return Byte_Count;
   function Value
     (Object : in out Handle) return not null Element_Array_Access
     with Pre => Is_Allocated (Object);
   --  Low-level scratch-storage borrow. The returned access becomes invalid
   --  after Ensure, Grow, or Release; logical collections use Owned_Vectors
   --  instead of exposing reserved capacity through this operation.
   function Element
     (Object : Handle;
      Index : Index_Type) return Element_Type
     with Pre => Contains (Object, Index);
   procedure Set_Element
     (Object : in out Handle;
      Index : Index_Type;
      Value : Element_Type)
     with Pre => Contains (Object, Index);

private
   type Handle is limited record
      Pointer : Element_Array_Access := null;
      Owner : Ownership.Budget_Owner;
   end record;
end Giflib.Internal.Owned_Arrays;
