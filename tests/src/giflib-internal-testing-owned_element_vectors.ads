with Giflib.Internal.Borrow_Guards;
with Giflib.Internal.Cleanup;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Vectors;
with Giflib.Internal.Ownership;

generic
   type Element_Type is limited private;
   --  The preflight must not mutate Element.  Once it returns True,
   --  Release_Contents consumes all nested resources; its outcome reports
   --  cleanup/accounting status rather than whether the resources remain.
   --  Completed callbacks are checkpointed.  If Release_Contents raises, it
   --  must tolerate retry of that same element after any partial work.
   with function Contents_Releasable
     (Element : Element_Type;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget) return Boolean;
   with function Release_Contents
     (Element : in out Element_Type;
      Budget : aliased in out Giflib.Internal.Ownership.Byte_Budget)
      return Giflib.Internal.Cleanup.Cleanup_Outcome;
package Giflib.Internal.Testing.Owned_Element_Vectors
  with Preelaborate
is
   package Borrow_Guards renames Giflib.Internal.Borrow_Guards;
   package Cleanup renames Giflib.Internal.Cleanup;
   package Ownership renames Giflib.Internal.Ownership;
   type Handle is limited private;

   function Append_New
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count;
      Index : out Positive) return Ownership.Allocation_Outcome;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome;

   function Length (Object : Handle) return Natural;
   function Is_Allocated (Object : Handle) return Boolean;
   function Is_Borrowed (Object : Handle) return Boolean;
   function Is_Cleanup_In_Progress (Object : Handle) return Boolean;
   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean;

   procedure Query
     (Object : in out Handle;
      Index : Positive;
      Process : not null access procedure (Value : Element_Type))
     with Pre => Index <= Length (Object)
                 and then not Is_Borrowed (Object)
                 and then not Is_Cleanup_In_Progress (Object);

   procedure Update
     (Object : in out Handle;
      Index : Positive;
      Process : not null access procedure (Value : in out Element_Type))
     with Pre => Index <= Length (Object)
                 and then not Is_Borrowed (Object)
                 and then not Is_Cleanup_In_Progress (Object);

private
   type Element_Access is access all Element_Type;
   type Index_Array is array (Positive range <>) of Element_Access;
   package Index_Storage is new Giflib.Internal.Owned_Arrays
     (Positive, Element_Access, Index_Array, null);
   package Indexes is new Giflib.Internal.Owned_Vectors
     (Element_Type => Element_Access, Storage => Index_Storage);

   type Handle is limited record
      Entries : Indexes.Handle;
      Borrow : aliased Borrow_Guards.State;
      Cleanup_Active : Boolean := False;
      Cleanup_Position : Natural := 0;
      Cleanup_Status : Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
   end record;
end Giflib.Internal.Testing.Owned_Element_Vectors;
