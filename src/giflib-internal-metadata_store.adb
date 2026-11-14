with Giflib.Internal.Metadata_Store.Queries;
with Giflib.Internal.Metadata_Store.Transactions;

package body Giflib.Internal.Metadata_Store is
   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome
   is
      Chunks_Released : Cleanup.Cleanup_Outcome;
      Entries_Released : Cleanup.Cleanup_Outcome;
   begin
      if not Extension_Nodes.Matches (Object.Entries, Budget)
        or else not Payload_Chunks.Matches (Object.Chunks, Budget)
      then
         return (Status => Cleanup.Cleanup_Owner_Mismatch);
      end if;
      Chunks_Released := Payload_Chunks.Release (Object.Chunks, Budget);
      Entries_Released := Extension_Nodes.Release (Object.Entries, Budget);
      if not Extension_Nodes.Is_Allocated (Object.Entries)
        and then not Payload_Chunks.Is_Allocated (Object.Chunks)
      then
         Object.Retained_Bytes := 0;
         Object.Pending := (State => Idle);
      end if;
      return
        (if not Cleanup.Succeeded (Chunks_Released)
         then Chunks_Released
         elsif not Cleanup.Succeeded (Entries_Released)
         then Entries_Released
         else Cleanup.Success);
   end Release;

   function Start
     (Object : in out Store;
      Retention : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Info : Metadata.Extension_Info) return Results.Result is
     (Transactions.Start
        (Object, Retention, Maximum_Allocation, Budget, Fault, Info));

   function Append
     (Object : in out Store;
      Data : Streams.Byte_Array;
      Maximum_Retained : Byte_Count;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State) return Results.Result is
     (Transactions.Append
        (Object, Data, Maximum_Retained, Maximum_Allocation, Budget, Fault));

   function Finish
     (Object : in out Store;
      Info : Metadata.Extension_Info) return Results.Result is
     (Transactions.Finish (Object, Info));

   function Count (Object : Store) return Natural is
     (Extension_Nodes.Length (Object.Entries));

   function Is_Released (Object : Store) return Boolean is
     (not Extension_Nodes.Is_Allocated (Object.Entries)
      and then not Payload_Chunks.Is_Allocated (Object.Chunks)
      and then Object.Retained_Bytes = 0
      and then Object.Pending.State = Idle);

   function Info_At
     (Object : Store;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result is
     (Queries.Info_At (Object, Index, Info));

   function Copy_Payload
     (Object : Store;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result is
     (Queries.Copy_Payload (Object, Index, Target, Count));

   function Chunk_Count
     (Object : Store;
      Index : Positive;
      Count : out Natural) return Results.Result is
     (Queries.Chunk_Count (Object, Index, Count));

   function Copy_Chunk
     (Object : Store;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result is
     (Queries.Copy_Chunk (Object, Index, Chunk_Index, Target, Count));
end Giflib.Internal.Metadata_Store;
