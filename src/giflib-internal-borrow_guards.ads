with Ada.Finalization;

package Giflib.Internal.Borrow_Guards
  with Preelaborate
is
   type State is limited private;

   function Is_Active (Object : State) return Boolean;

   type Guard (Object : not null access State) is
     new Ada.Finalization.Limited_Controlled with private;

private
   type State is limited record
      Active : Boolean := False;
   end record;

   type Guard (Object : not null access State) is
     new Ada.Finalization.Limited_Controlled with record
      Acquired : Boolean := False;
   end record;

   overriding procedure Initialize (Object : in out Guard);
   overriding procedure Finalize (Object : in out Guard);
end Giflib.Internal.Borrow_Guards;
