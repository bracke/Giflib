with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Cleanup;
with Giflib.Internal.Ownership;

generic
   type Element_Type is private;
   with package Storage is new Owned_Arrays
     (Index_Type => Positive,
      Element_Type => Element_Type,
      Element_Array => <>,
      Default_Element => <>);
   Initial_Capacity : Positive := 16;
package Giflib.Internal.Owned_Vectors is
   pragma Preelaborate;

   type Handle is limited private;

   function Ensure_Append
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;
   --  Ensures room for one more element. Failure leaves Object unchanged.

   function Is_Allocated (Object : Handle) return Boolean;
   function Length (Object : Handle) return Natural;
   function Capacity (Object : Handle) return Natural;
   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean;

   procedure Append
     (Object : in out Handle;
      Value : Element_Type)
     with Pre => Length (Object) < Capacity (Object),
          Post => Length (Object) = Length (Object)'Old + 1
                  and then Element (Object, Length (Object)) = Value;

   procedure Replace
     (Object : in out Handle;
      Index : Positive;
      Value : Element_Type)
     with Pre => Index <= Length (Object),
          Post => Length (Object) = Length (Object)'Old
                  and then Element (Object, Index) = Value;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome;

   function Element
     (Object : Handle;
      Index : Positive) return Element_Type
     with Pre => Index <= Length (Object);

private
   type Handle is limited record
      Data : Storage.Handle;
      Count : Natural := 0;
   end record
     with Type_Invariant => Count <= Storage.Length (Data);
end Giflib.Internal.Owned_Vectors;
