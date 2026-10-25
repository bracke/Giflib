with Giflib.Internal.Borrow_Guards;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Vectors;
with Giflib.Internal.Ownership;

generic
   type Element_Type is limited private;
   with function Release_Contents
     (Element : in out Element_Type;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
package Giflib.Internal.Owned_Element_Vectors
  with Preelaborate
is
   type Handle is limited private;

   function Append_New
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count;
      Index : out Positive) return Ownership.Allocation_Outcome;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;

   function Length (Object : Handle) return Natural;
   function Is_Allocated (Object : Handle) return Boolean;
   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean;

   function Element
     (Object : Handle;
      Index : Positive) return not null access constant Element_Type
     with Pre => Index <= Length (Object);

   procedure Update
     (Object : in out Handle;
      Index : Positive;
      Process : not null access procedure (Value : in out Element_Type))
     with Pre => Index <= Length (Object);

private
   type Element_Access is access all Element_Type;
   type Index_Array is array (Positive range <>) of Element_Access;
   package Index_Storage is new Owned_Arrays
     (Positive, Element_Access, Index_Array, null);
   package Indexes is new Owned_Vectors
     (Element_Type => Element_Access, Storage => Index_Storage);

   type Handle is limited record
      Entries : Indexes.Handle;
      Borrow : aliased Borrow_Guards.State;
   end record;
end Giflib.Internal.Owned_Element_Vectors;
