with Ada.Finalization;
with Giflib.Internal.Cleanup;
with Giflib.Internal.Ownership;

package Giflib.Internal.Resource_Cleanup is
   pragma Preelaborate;

   type Guard
     (Budget : not null access Ownership.Byte_Budget;
      Sticky_Status : not null access Cleanup.Cleanup_Status)
      is new Ada.Finalization.Limited_Controlled with private;

   generic
      with function Release_Operation return Cleanup.Cleanup_Outcome;
   procedure Attempt (Object : in out Guard);

   overriding procedure Finalize (Object : in out Guard);

private
   type Guard
     (Budget : not null access Ownership.Byte_Budget;
      Sticky_Status : not null access Cleanup.Cleanup_Status)
      is new Ada.Finalization.Limited_Controlled with record
      Status : Cleanup.Cleanup_Status := Cleanup.Cleanup_Complete;
   end record;
end Giflib.Internal.Resource_Cleanup;
