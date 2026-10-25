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

   function Is_Borrowed (Buffer : Handle) return Boolean is
     (Storage.Is_Borrowed (Buffer.Owner));

   function Length (Buffer : Handle) return Byte_Count is
     (Byte_Count (Storage.Length (Buffer.Owner)));

   procedure Query
     (Buffer : in out Handle;
      Process : not null access procedure (Value : Streams.Byte_Array)) is
   begin
      Storage.Query (Buffer.Owner, Process);
   end Query;

   procedure Update
     (Buffer : in out Handle;
      Process : not null access procedure
        (Value : in out Streams.Byte_Array)) is
   begin
      Storage.Update (Buffer.Owner, Process);
   end Update;

   procedure Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access procedure
        (Source_Value : Streams.Byte_Array;
         Target_Value : in out Streams.Byte_Array)) is
   begin
      Storage.Query_Update (Source.Owner, Target.Owner, Process);
   end Query_Update;
end Giflib.Internal.Owned_Buffers;
