with Ada.Unchecked_Deallocation;

with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Metadata_Store is
   use type Ownership.Allocation_Status;
   use type Metadata.Extension_Kind;
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;

   procedure Free_Chunk is new Ada.Unchecked_Deallocation
     (Payload_Chunk, Payload_Chunk_Access);
   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Extension_Node, Extension_Node_Access);

   function Node_Charge return Byte_Count is
     (Ownership.Storage_Bytes (Extension_Node'Object_Size));

   function Chunk_Charge return Byte_Count is
     (Ownership.Storage_Bytes (Payload_Chunk'Object_Size));

   function Allocation_Error
     (Info       : Metadata.Extension_Info;
      Maximum    : Byte_Count;
      Allocation : Ownership.Allocation_Outcome) return Results.Result
   is
   begin
      return Results.Failure
        (Resource_Diagnostics.Allocation_Error
           (Allocation,
            Maximum,
            Allocation.Attempted,
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
      Node : Extension_Node_Access;
      Chunk : Payload_Chunk_Access;
      Ledger_Released : Boolean;
      Released : Boolean := True;

      procedure Release_Charge (Amount : Byte_Count) is
      begin
         Ledger_Released := Ownership.Release (Budget, Amount);
         Released := Ledger_Released and Released;
      end Release_Charge;
   begin
      if not Ownership.Matches (Object.Owner, Budget) then
         return False;
      end if;
      for Index in 1 .. Extension_Indexes.Length (Object.Entries) loop
         Node := Extension_Indexes.Element (Object.Entries, Index);
         for Chunk_Index in 1 .. Chunk_Indexes.Length (Node.Chunks) loop
            Chunk := Chunk_Indexes.Element (Node.Chunks, Chunk_Index);
            Release_Charge (Chunk_Charge);
            Free_Chunk (Chunk);
         end loop;
         Ledger_Released := Chunk_Indexes.Release (Node.Chunks, Budget);
         Released := Ledger_Released and Released;
         Release_Charge (Node_Charge);
         Free_Node (Node);
      end loop;
      Ledger_Released := Extension_Indexes.Release (Object.Entries, Budget);
      Released := Ledger_Released and Released;
      Object.Retained_Bytes := 0;
      Object.Pending := (State => Idle);
      Ledger_Released := Ownership.Release_Owned (Object.Owner, Budget, 0);
      Released := Ledger_Released and Released;
      return Released;
   end Release;

   function Start
     (Object             : in out Store;
      Retention          : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State;
      Info               : Metadata.Extension_Info) return Results.Result
   is
      Node : Extension_Node_Access;
      Allocation : Ownership.Allocation_Outcome;

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
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source_Position => Errors.Source_Position_At (Info.Offset),
                Block => Arithmetic.Block_For (Info.Kind),
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                others => <>)));
      end if;
      Allocation := Extension_Indexes.Ensure_Append
        (Object.Entries, Budget, Fault, Maximum_Allocation);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Info, Maximum_Allocation, Allocation);
      end if;
      Ownership.Bind (Object.Owner, Budget);
      declare
         Ticket : Ownership.Reservation (Budget'Access);
         procedure Allocate is
         begin
            Node := new Extension_Node'(Info => Info, others => <>);
         end Allocate;
         procedure Perform is new Ownership.Reserve_And_Allocate (Allocate);
      begin
         Perform (Ticket, Fault, Maximum_Allocation, Node_Charge, Allocation);
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Info, Maximum_Allocation, Allocation);
      end if;
      Extension_Indexes.Append (Object.Entries, Node);
      Object.Pending :=
        (State => Building, Index => Extension_Indexes.Length (Object.Entries));
      return Results.Success;
   end Start;

   function Append
     (Object             : in out Store;
      Data               : Streams.Byte_Array;
      Maximum_Retained   : Byte_Count;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State) return Results.Result
   is
      Chunk : Payload_Chunk_Access;
      Node : Extension_Node_Access;
      Allocation : Ownership.Allocation_Outcome;

   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Object.Pending.State = Ignoring or else Data'Length = 0 then
         return Results.Success;
      elsif not Ownership.Matches (Object.Owner, Budget) then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Node := Extension_Indexes.Element
        (Object.Entries, Object.Pending.Index);
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
                  (Object.Retained_Bytes,
                   Byte_Count'Last,
                   Byte_Count (Data'Length)).Attempted,
                Limit => Retained_Metadata_Byte_Limit,
                others => <>)));
      end if;
      Allocation := Chunk_Indexes.Ensure_Append
        (Node.Chunks, Budget, Fault, Maximum_Allocation);
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Node.Info, Maximum_Allocation, Allocation);
      end if;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
         procedure Allocate is
         begin
            Chunk := new Payload_Chunk;
         end Allocate;
         procedure Perform is new Ownership.Reserve_And_Allocate (Allocate);
      begin
         Perform (Ticket, Fault, Maximum_Allocation, Chunk_Charge, Allocation);
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error (Node.Info, Maximum_Allocation, Allocation);
      end if;
      Chunk.Length := Data'Length;
      for I in 0 .. Data'Length - 1 loop
         Chunk.Data (Chunk.Data'First + I) := Data (Data'First + I);
      end loop;
      Chunk_Indexes.Append (Node.Chunks, Chunk);
      Node.Retained_Length := Node.Retained_Length + Byte_Count (Data'Length);
      Object.Retained_Bytes := Arithmetic.Appended_Length
        (Object.Retained_Bytes, Maximum_Retained, Data'Length);
      return Results.Success;
   end Append;

   function Finish
     (Object : in out Store;
      Info   : Metadata.Extension_Info) return Results.Result
   is
      Node : Extension_Node_Access;
   begin
      if Object.Pending.State = Idle then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      if Object.Pending.State = Building then
         Node := Extension_Indexes.Element
           (Object.Entries, Object.Pending.Index);
         Node.Info := Info;
         Node.Info.Payload_Length := Node.Retained_Length;
      end if;
      Object.Pending := (State => Idle);
      return Results.Success;
   end Finish;

   function Find
     (Object : Store;
      Index  : Positive) return Extension_Node_Access
   is
   begin
      if Index > Extension_Indexes.Length (Object.Entries) then
         return null;
      end if;
      return Extension_Indexes.Element (Object.Entries, Index);
   end Find;

   function Count (Object : Store) return Natural is
     (Extension_Indexes.Length (Object.Entries));

   function Is_Released (Object : Store) return Boolean is
     (not Extension_Indexes.Is_Allocated (Object.Entries)
      and then Object.Retained_Bytes = 0
      and then Object.Pending.State = Idle
      and then not Ownership.Is_Bound (Object.Owner));

   function Info_At
     (Object : Store;
      Index  : Positive;
      Info   : out Metadata.Extension_Info) return Results.Result
   is
      Node : constant Extension_Node_Access := Find (Object, Index);
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
      Index  : Positive;
      Target : out Streams.Byte_Array;
      Count  : out Byte_Count) return Results.Result
   is
      Node : constant Extension_Node_Access := Find (Object, Index);
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
                Actual => Byte_Count (Target'Length),
                others => <>)));
      end if;
      for Chunk_Index in 1 .. Chunk_Indexes.Length (Node.Chunks) loop
         declare
            Chunk : constant Payload_Chunk_Access :=
              Chunk_Indexes.Element (Node.Chunks, Chunk_Index);
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
      Index  : Positive;
      Count  : out Natural) return Results.Result
   is
      Node : constant Extension_Node_Access := Find (Object, Index);
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Count := Chunk_Indexes.Length (Node.Chunks);
      return Results.Success;
   end Chunk_Count;

   function Copy_Chunk
     (Object      : Store;
      Index       : Positive;
      Chunk_Index : Positive;
      Target      : out Streams.Byte_Array;
      Count       : out Byte_Count) return Results.Result
   is
      Node : constant Extension_Node_Access := Find (Object, Index);
      Chunk : Payload_Chunk_Access;
   begin
      Count := 0;
      if Node = null
        or else Chunk_Index > Chunk_Indexes.Length (Node.Chunks)
      then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Chunk := Chunk_Indexes.Element (Node.Chunks, Chunk_Index);
      if Target'Length < Chunk.Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Byte_Count (Chunk.Length),
                Actual => Byte_Count (Target'Length),
                others => <>)));
      end if;
      for I in 0 .. Chunk.Length - 1 loop
         Target (Target'First + I) := Chunk.Data (Chunk.Data'First + I);
      end loop;
      Count := Byte_Count (Chunk.Length);
      return Results.Success;
   end Copy_Chunk;
end Giflib.Internal.Metadata_Store;
