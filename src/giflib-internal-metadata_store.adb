with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Metadata_Store is
   use type Ownership.Allocation_Status;
   use type Metadata.Extension_Kind;
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;

   function Release_Payload
     (Element : in out Payload_Chunk;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      pragma Unreferenced (Element, Budget);
   begin
      return True;
   end Release_Payload;

   function Release_Node
     (Element : in out Extension_Node;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean is
   begin
      return Payload_Chunks.Release (Element.Chunks, Budget);
   end Release_Node;

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
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Released : Boolean;
      Owner_Released : Boolean;
   begin
      if not Ownership.Matches (Object.Owner, Budget) then
         return False;
      end if;
      Released := Extension_Nodes.Release (Object.Entries, Budget);
      Object.Retained_Bytes := 0;
      Object.Pending := (State => Idle);
      Owner_Released := Ownership.Release_Owned (Object.Owner, Budget, 0);
      return Released and Owner_Released;
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
      procedure Initialize (Node : in out Extension_Node) is
      begin
         Node.Info := Info;
      end Initialize;
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
      elsif not Ownership.Matches (Object.Owner, Budget) then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Allocation := Extension_Nodes.Append_New
        (Object.Entries, Budget, Fault, Maximum_Allocation, Index);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Info, Maximum_Allocation, Allocation);
      end if;
      Ownership.Bind (Object.Owner, Budget);
      Extension_Nodes.Update (Object.Entries, Index, Initialize'Access);
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
      Node : access constant Extension_Node;
      Outcome : Results.Result := Results.Success;

      procedure Append_To (Value : in out Extension_Node) is
         Allocation : Ownership.Allocation_Outcome;
         Chunk_Index : Positive;
         procedure Store_Data (Chunk : in out Payload_Chunk) is
         begin
            Chunk.Length := Data'Length;
            for I in 0 .. Data'Length - 1 loop
               Chunk.Data (Chunk.Data'First + I) := Data (Data'First + I);
            end loop;
         end Store_Data;
      begin
         Allocation := Payload_Chunks.Append_New
           (Value.Chunks, Budget, Fault, Maximum_Allocation, Chunk_Index);
         if Allocation.Status /= Ownership.Allocation_Ready then
            Outcome := Allocation_Error
              (Value.Info, Maximum_Allocation, Allocation);
            return;
         end if;
         Payload_Chunks.Update (Value.Chunks, Chunk_Index, Store_Data'Access);
         Value.Retained_Length :=
           Value.Retained_Length + Byte_Count (Data'Length);
      end Append_To;
   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Object.Pending.State = Ignoring or else Data'Length = 0 then
         return Results.Success;
      elsif not Ownership.Matches (Object.Owner, Budget) then
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
      Extension_Nodes.Update
        (Object.Entries, Object.Pending.Index, Append_To'Access);
      if Results.Succeeded (Outcome) then
         Object.Retained_Bytes := Arithmetic.Appended_Length
           (Object.Retained_Bytes, Maximum_Retained, Data'Length);
      end if;
      return Outcome;
   end Append;

   function Finish
     (Object : in out Store;
      Info : Metadata.Extension_Info) return Results.Result
   is
      procedure Complete (Node : in out Extension_Node) is
      begin
         Node.Info := Info;
         Node.Info.Payload_Length := Node.Retained_Length;
      end Complete;
   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Object.Pending.State = Building then
         Extension_Nodes.Update
           (Object.Entries, Object.Pending.Index, Complete'Access);
      end if;
      Object.Pending := (State => Idle);
      return Results.Success;
   end Finish;

   function Find
     (Object : Store;
      Index : Positive) return access constant Extension_Node is
   begin
      if Index > Extension_Nodes.Length (Object.Entries) then
         return null;
      end if;
      return Extension_Nodes.Element (Object.Entries, Index);
   end Find;

   function Count (Object : Store) return Natural is
     (Extension_Nodes.Length (Object.Entries));

   function Is_Released (Object : Store) return Boolean is
     (not Extension_Nodes.Is_Allocated (Object.Entries)
      and then Object.Retained_Bytes = 0
      and then Object.Pending.State = Idle
      and then not Ownership.Is_Bound (Object.Owner));

   function Info_At
     (Object : Store;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result
   is
      Node : constant access constant Extension_Node := Find (Object, Index);
   begin
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      elsif Info'Constrained and then Info.Kind /= Node.Info.Kind then
         return Results.Failure
           (Errors.Make
              (Errors.Output_Variant_Mismatch,
               (Expected => Byte_Count (Metadata.Extension_Kind'Pos (Info.Kind)),
                Actual => Byte_Count (Metadata.Extension_Kind'Pos (Node.Info.Kind)),
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
      Node : constant access constant Extension_Node := Find (Object, Index);
      Position : Natural := 0;
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      elsif Byte_Count (Target'Length) < Node.Retained_Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Node.Retained_Length,
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      for Chunk_Index in 1 .. Payload_Chunks.Length (Node.Chunks) loop
         declare
            Chunk : constant access constant Payload_Chunk :=
              Payload_Chunks.Element (Node.Chunks, Chunk_Index);
         begin
            for I in 0 .. Chunk.Length - 1 loop
               Target (Target'First + Position) :=
                 Chunk.Data (Chunk.Data'First + I);
               Position := Position + 1;
            end loop;
         end;
      end loop;
      Count := Byte_Count (Position);
      return Results.Success;
   end Copy_Payload;

   function Chunk_Count
     (Object : Store;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
      Node : constant access constant Extension_Node := Find (Object, Index);
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Count := Payload_Chunks.Length (Node.Chunks);
      return Results.Success;
   end Chunk_Count;

   function Copy_Chunk
     (Object : Store;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Node : constant access constant Extension_Node := Find (Object, Index);
      Chunk : access constant Payload_Chunk;
   begin
      Count := 0;
      if Node = null
        or else Chunk_Index > Payload_Chunks.Length (Node.Chunks)
      then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Chunk := Payload_Chunks.Element (Node.Chunks, Chunk_Index);
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
