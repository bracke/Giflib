package body Giflib.Internal.Resource_Cleanup is
   procedure Release_Three
     (Budget : Ownership.Byte_Budget;
      Sticky_Failure : in out Boolean)
   is
      Failed : Boolean := False;
      procedure Try_First is new Ownership.Attempt_Release (Release_First);
      procedure Try_Second is new Ownership.Attempt_Release (Release_Second);
      procedure Try_Third is new Ownership.Attempt_Release (Release_Third);
   begin
      Try_First (Failed);
      Try_Second (Failed);
      Try_Third (Failed);
      Sticky_Failure :=
        Sticky_Failure or else Failed or else not Ownership.Healthy (Budget);
   end Release_Three;

   procedure Release_Five
     (Budget : Ownership.Byte_Budget;
      Sticky_Failure : in out Boolean)
   is
      Failed : Boolean := False;
      procedure Try_First is new Ownership.Attempt_Release (Release_First);
      procedure Try_Second is new Ownership.Attempt_Release (Release_Second);
      procedure Try_Third is new Ownership.Attempt_Release (Release_Third);
      procedure Try_Fourth is new Ownership.Attempt_Release (Release_Fourth);
      procedure Try_Fifth is new Ownership.Attempt_Release (Release_Fifth);
   begin
      Try_First (Failed);
      Try_Second (Failed);
      Try_Third (Failed);
      Try_Fourth (Failed);
      Try_Fifth (Failed);
      Sticky_Failure :=
        Sticky_Failure or else Failed or else not Ownership.Healthy (Budget);
   end Release_Five;
end Giflib.Internal.Resource_Cleanup;
