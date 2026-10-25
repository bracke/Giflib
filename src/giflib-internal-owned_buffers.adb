package body Giflib.Internal.Owned_Buffers is
   function Ensure
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
   begin
      return Storage.Ensure
        (Buffer.Owner, Budget, Fault, 1, Natural (Required), Maximum);
   end Ensure;

   function Release
     (Buffer : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
   begin
      return Storage.Release (Buffer.Owner, Budget);
   end Release;

   function Is_Allocated (Buffer : Handle) return Boolean is
     (Storage.Is_Allocated (Buffer.Owner));

   function Length (Buffer : Handle) return Byte_Count is
     (Byte_Count (Storage.Length (Buffer.Owner)));

   function Value
     (Buffer : in out Handle) return not null Byte_Array_Access is
     (Storage.Value (Buffer.Owner));
end Giflib.Internal.Owned_Buffers;
