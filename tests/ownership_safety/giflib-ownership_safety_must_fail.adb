with Ada.Finalization;
with Giflib.Internal.Owned_Objects;

procedure Giflib.Ownership_Safety_Must_Fail is
   type Controlled_Element is
     new Ada.Finalization.Limited_Controlled with null record;
   package Unsafe is new Giflib.Internal.Owned_Objects (Controlled_Element);
   Object : Unsafe.Handle;
   pragma Unreferenced (Object);
begin
   null;
end Giflib.Ownership_Safety_Must_Fail;
