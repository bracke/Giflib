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
   function Is_Borrowed (Object : Handle) return Boolean;
   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean;
   function Contains
     (Object : Handle;
      Index : Index_Type) return Boolean;
   --  Contains describes allocated capacity. Every contained slot always has a
   --  defined value; higher-level collections may impose a smaller logical
   --  length before exposing their contents.
   function Length (Object : Handle) return Natural;
   function Allocation_Bytes (Length : Natural) return Byte_Count;
   procedure Query
     (Object : in out Handle;
      Process : not null access procedure (Value : Element_Array))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);
   procedure Update
     (Object : in out Handle;
      Process : not null access procedure (Value : in out Element_Array))
     with Pre => Is_Allocated (Object) and then not Is_Borrowed (Object);
   procedure Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access procedure
        (Source_Value : Element_Array;
         Target_Value : in out Element_Array))
     with Pre => Is_Allocated (Source)
                 and then Is_Allocated (Target)
                 and then not Is_Borrowed (Source)
                 and then not Is_Borrowed (Target);
   --  Scratch storage is visible only for the dynamic extent of Process.
   --  Logical collections use Owned_Vectors instead of exposing capacity.
   function Element
     (Object : Handle;
      Index : Index_Type) return Element_Type
     with Pre => Contains (Object, Index);
   procedure Set_Element
     (Object : in out Handle;
      Index : Index_Type;
      Value : Element_Type)
     with Pre => Contains (Object, Index) and then not Is_Borrowed (Object);

private
   type Element_Array_Access is access all Element_Array;
   type Handle is limited record
      Pointer : Element_Array_Access := null;
      Owner : Ownership.Budget_Owner;
      Borrowed : Boolean := False;
   end record;
end Giflib.Internal.Owned_Arrays;
