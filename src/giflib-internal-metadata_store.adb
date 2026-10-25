with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Metadata_Store is
   use type Ownership.Allocation_Status;
   use type Metadata.Extension_Kind;
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;

   function Allocation_Error
     (Info : Metadata.Extension_Info;
      Maximum : Byte_Count;
      Allocation : Ownership.Allocation_Outcome) return Results.Result is
   begin
      return Results.Failure
        (Resource_Diagnostics.Allocation_Error
           (Allocation, Maximum, Allocation.Attempted,
            (Source_Position => Errors.Source_Position_At (Info.Offset),
             Block => Arithmetic.Block_For (Info.Kind),
             Extension_Label =>
               Errors.Extension_Label_At (Metadata.Label_Of (Info)),
             others => <>)));
   end Allocation_Error;

   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome
   is
      Chunks_Released : Boolean;
      Entries_Released : Boolean;
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
        (if Chunks_Released and then Entries_Released
         then Cleanup.Success
         else (Status => Cleanup.Cleanup_Accounting_Failed));
   end Release;

   function Start
     (Object : in out Store;
      Retention : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Info : Metadata.Extension_Info) return Results.Result
   is
      Allocation : Ownership.Allocation_Outcome;
      Index : Positive;
   begin
      if Object.Pending.State /= Idle then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_State,
               (Source_Position => Errors.Source_Position_At (Info.Offset),
                Block => Arithmetic.Block_For (Info.Kind),
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                others => <>)));
      elsif not Arithmetic.Should_Retain (Retention, Info.Kind) then
         Object.Pending := (State => Ignoring);
         return Results.Success;
      elsif not Extension_Nodes.Matches (Object.Entries, Budget)
        or else not Payload_Chunks.Matches (Object.Chunks, Budget)
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Allocation := Extension_Nodes.Ensure_Append
        (Object.Entries, Budget, Fault, Maximum_Allocation);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Info, Maximum_Allocation, Allocation);
      end if;
      Index := Extension_Nodes.Length (Object.Entries) + 1;
      Extension_Nodes.Append
        (Object.Entries,
         (Info => Info, First_Chunk => 0, Chunk_Count => 0,
          Retained_Length => 0));
      Object.Pending := (State => Building, Index => Index);
      return Results.Success;
   end Start;

   function Append
     (Object : in out Store;
      Data : Streams.Byte_Array;
      Maximum_Retained : Byte_Count;
      Maximum_Allocation : Byte_Count;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State) return Results.Result
   is
      Node : Extension_Node;
      Allocation : Ownership.Allocation_Outcome;
      Chunk : Payload_Chunk;
   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Object.Pending.State = Ignoring or else Data'Length = 0 then
         return Results.Success;
      elsif not Extension_Nodes.Matches (Object.Entries, Budget)
        or else not Payload_Chunks.Matches (Object.Chunks, Budget)
      then
         return Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Object.Pending.Index);
      if Data'Length > 255 then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source_Position => Errors.Source_Position_At (Node.Info.Offset),
                Block => Arithmetic.Block_For (Node.Info.Kind),
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Node.Info)),
                others => <>)));
      elsif not Arithmetic.Can_Append
        (Object.Retained_Bytes, Maximum_Retained, Data'Length)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source_Position => Errors.Source_Position_At (Node.Info.Offset),
                Block => Arithmetic.Block_For (Node.Info.Kind),
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Node.Info)),
                Expected => Maximum_Retained,
                Actual => Budget_Arithmetic.Charge
                  (Object.Retained_Bytes, Byte_Count'Last,
                   Byte_Count (Data'Length)).Attempted,
                Limit => Retained_Metadata_Byte_Limit,
                others => <>)));
      end if;
      Chunk.Length := Data'Length;
      for I in 0 .. Data'Length - 1 loop
         Chunk.Data (Chunk.Data'First + I) := Data (Data'First + I);
      end loop;
      Allocation := Payload_Chunks.Ensure_Append
        (Object.Chunks, Budget, Fault, Maximum_Allocation);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Node.Info, Maximum_Allocation, Allocation);
      end if;
      if Node.Chunk_Count = 0 then
         Node.First_Chunk := Payload_Chunks.Length (Object.Chunks) + 1;
      end if;
      Payload_Chunks.Append (Object.Chunks, Chunk);
      Node.Chunk_Count := Node.Chunk_Count + 1;
      Node.Retained_Length :=
        Node.Retained_Length + Byte_Count (Data'Length);
      Extension_Nodes.Replace
        (Object.Entries, Object.Pending.Index, Node);
      Object.Retained_Bytes := Arithmetic.Appended_Length
        (Object.Retained_Bytes, Maximum_Retained, Data'Length);
      return Results.Success;
   end Append;

   function Finish
     (Object : in out Store;
      Info : Metadata.Extension_Info) return Results.Result
   is
      Node : Extension_Node;
   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Object.Pending.State = Building then
         Node := Extension_Nodes.Element
           (Object.Entries, Object.Pending.Index);
         Node.Info := Info;
         Node.Info.Payload_Length := Node.Retained_Length;
         Extension_Nodes.Replace
           (Object.Entries, Object.Pending.Index, Node);
      end if;
      Object.Pending := (State => Idle);
      return Results.Success;
   end Finish;

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
      Info : out Metadata.Extension_Info) return Results.Result
   is
      Node : Extension_Node;
   begin
      if Index > Extension_Nodes.Length (Object.Entries) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Index);
      if Info'Constrained and then Info.Kind /= Node.Info.Kind then
         return Results.Failure
           (Errors.Make
              (Errors.Output_Variant_Mismatch,
               (Expected => Byte_Count (Metadata.Extension_Kind'Pos (Info.Kind)),
                Actual => Byte_Count
                  (Metadata.Extension_Kind'Pos (Node.Info.Kind)),
                others => <>)));
      end if;
      Info := Node.Info;
      return Results.Success;
   end Info_At;

   function Copy_Payload
     (Object : Store;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Position : Natural := 0;
      Node : Extension_Node;
      Chunk : Payload_Chunk;
   begin
      Count := 0;
      if Index > Extension_Nodes.Length (Object.Entries) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Index);
      if Byte_Count (Target'Length) < Node.Retained_Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Node.Retained_Length,
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      if Node.Chunk_Count > 0 then
         for Offset in 0 .. Node.Chunk_Count - 1 loop
            Chunk := Payload_Chunks.Element
              (Object.Chunks, Node.First_Chunk + Offset);
            for I in 0 .. Chunk.Length - 1 loop
               Target (Target'First + Position) :=
                 Chunk.Data (Chunk.Data'First + I);
               Position := Position + 1;
            end loop;
         end loop;
      end if;
      Count := Byte_Count (Position);
      return Results.Success;
   end Copy_Payload;

   function Chunk_Count
     (Object : Store;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
   begin
      Count := 0;
      if Index > Extension_Nodes.Length (Object.Entries) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Count := Extension_Nodes.Element (Object.Entries, Index).Chunk_Count;
      return Results.Success;
   end Chunk_Count;

   function Copy_Chunk
     (Object : Store;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Node : Extension_Node;
      Chunk : Payload_Chunk;
   begin
      Count := 0;
      if Index > Extension_Nodes.Length (Object.Entries) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Index);
      if Chunk_Index > Node.Chunk_Count then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Chunk := Payload_Chunks.Element
        (Object.Chunks, Node.First_Chunk + Chunk_Index - 1);
      if Target'Length < Chunk.Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Byte_Count (Chunk.Length),
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      for I in 0 .. Chunk.Length - 1 loop
         Target (Target'First + I) := Chunk.Data (Chunk.Data'First + I);
      end loop;
      Count := Byte_Count (Chunk.Length);
      return Results.Success;
   end Copy_Chunk;
end Giflib.Internal.Metadata_Store;
