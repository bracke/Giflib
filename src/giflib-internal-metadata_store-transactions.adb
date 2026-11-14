with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Internal.Metadata_Store.Validation;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Metadata_Store.Transactions is
   use type Ownership.Allocation_Status;
   use type Metadata.Extension_Kind;
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;
   package Checks renames Giflib.Internal.Metadata_Store.Validation;

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

   function Same_Identity
     (Left : Metadata.Extension_Info;
      Right : Metadata.Extension_Info) return Boolean
   is
     (Left.Kind = Right.Kind
      and then Left.Offset = Right.Offset
      and then Left.Before_Frame = Right.Before_Frame
      and then Metadata.Label_Of (Left) = Metadata.Label_Of (Right));

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
         return Checks.Invalid_Store;
      end if;
      Allocation := Extension_Nodes.Ensure_Append
        (Object.Entries, Budget, Fault, Maximum_Allocation);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Info, Maximum_Allocation, Allocation);
      end if;
      Index := Extension_Nodes.Length (Object.Entries) + 1;
      Extension_Nodes.Append
        (Object.Entries, (Info => Info, Span => (Present => False)));
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
         return Checks.Invalid_Store;
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Object.Pending.Index);
      if not Checks.Node_Is_Valid (Object, Object.Pending.Index, Node) then
         return Checks.Invalid_Store;
      end if;
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
      elsif Node.Span.Present and then Node.Span.Count = Positive'Last then
         return Checks.Invalid_Store;
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
      Payload_Chunks.Append (Object.Chunks, Chunk);
      Node.Span :=
        (if not Node.Span.Present
         then
           (Present => True,
            First => Payload_Chunks.Length (Object.Chunks),
            Count => 1,
            Length => Byte_Count (Data'Length))
         else
           (Present => True,
            First => Node.Span.First,
            Count => Node.Span.Count + 1,
            Length => Node.Span.Length + Byte_Count (Data'Length)));
      Extension_Nodes.Replace (Object.Entries, Object.Pending.Index, Node);
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
         if not Results.Succeeded
           (Checks.Load_Node (Object, Object.Pending.Index, Node))
         then
            return Checks.Invalid_Store;
         elsif not Same_Identity (Node.Info, Info) then
            return Checks.Invalid_Store;
         end if;
         Node.Info := Info;
         Node.Info.Payload_Length := Checks.Stored_Length (Node);
         Node.Info.Sub_Block_Count := Checks.Stored_Chunk_Count (Node);
         Extension_Nodes.Replace (Object.Entries, Object.Pending.Index, Node);
      end if;
      Object.Pending := (State => Idle);
      return Results.Success;
   end Finish;
end Giflib.Internal.Metadata_Store.Transactions;
