with Giflib.Internal.Ownership;

package Giflib.Internal.Resource_Cleanup is
   pragma Preelaborate;

   generic
      with function Release_First return Boolean;
      with function Release_Second return Boolean;
      with function Release_Third return Boolean;
   procedure Release_Three
     (Budget : Ownership.Byte_Budget;
      Sticky_Failure : in out Boolean);

   generic
      with function Release_First return Boolean;
      with function Release_Second return Boolean;
      with function Release_Third return Boolean;
      with function Release_Fourth return Boolean;
      with function Release_Fifth return Boolean;
   procedure Release_Five
     (Budget : Ownership.Byte_Budget;
      Sticky_Failure : in out Boolean);
end Giflib.Internal.Resource_Cleanup;
