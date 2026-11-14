private package Giflib.Internal.Metadata_Store.Transactions is
   pragma Preelaborate;

   function Start
     (Object : in out Store;
      Retention : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Info : Metadata.Extension_Info) return Results.Result;
   function Append
     (Object : in out Store;
      Data : Streams.Byte_Array;
      Maximum_Retained : Byte_Count;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State) return Results.Result;
   function Finish
     (Object : in out Store;
      Info : Metadata.Extension_Info) return Results.Result;
end Giflib.Internal.Metadata_Store.Transactions;
