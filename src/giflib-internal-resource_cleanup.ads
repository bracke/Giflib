with Ada.Finalization;
with Giflib.Internal.Ownership;

package Giflib.Internal.Resource_Cleanup is
   pragma Preelaborate;

   type Guard
     (Budget : not null access Ownership.Byte_Budget;
      Sticky_Failure : not null access Boolean)
      is new Ada.Finalization.Limited_Controlled with private;

   generic
      with function Release_Operation return Boolean;
   procedure Attempt (Object : in out Guard);

   overriding procedure Finalize (Object : in out Guard);

private
   type Guard
     (Budget : not null access Ownership.Byte_Budget;
      Sticky_Failure : not null access Boolean)
      is new Ada.Finalization.Limited_Controlled with record
      Failed : Boolean := False;
   end record;
end Giflib.Internal.Resource_Cleanup;
