with Ada.Unchecked_Deallocation;

with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;

package body Giflib.Internal.Metadata_Store is
   use type Ownership.Allocation_Status;
   use type System.Address;
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;

   procedure Free_Chunk is new Ada.Unchecked_Deallocation
     (Payload_Chunk, Payload_Chunk_Access);
   procedure Free_Chunk_Index is new Ada.Unchecked_Deallocation
     (Chunk_Index_Array, Chunk_Index_Access);
   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Extension_Node, Extension_Node_Access);
   procedure Free_Extension_Index is new Ada.Unchecked_Deallocation
     (Extension_Index_Array, Extension_Index_Access);

   Initial_Index_Capacity : constant := 16;

   function Node_Charge return Byte_Count is
     (Ownership.Storage_Bytes (Extension_Node'Object_Size));

   function Chunk_Charge return Byte_Count is
     (Ownership.Storage_Bytes (Payload_Chunk'Object_Size));

   function Extension_Index_Charge (Capacity : Natural) return Byte_Count is
     (Byte_Count (Capacity)
      * Ownership.Storage_Bytes (Extension_Node_Access'Object_Size));

   function Chunk_Index_Charge (Capacity : Natural) return Byte_Count is
     (Byte_Count (Capacity)
      * Ownership.Storage_Bytes (Payload_Chunk_Access'Object_Size));

   function Next_Capacity
     (Current  : Natural;
      Required : Positive) return Positive
   is
      Result : Natural := Natural'Max (Current, Initial_Index_Capacity);
   begin
      while Result < Required loop
         if Result > Natural'Last / 2 then
            return Required;
         end if;
         Result := Result * 2;
      end loop;
      return Positive (Result);
   end Next_Capacity;

   function Allocation_Error
     (Info     : Metadata.Extension_Info;
      Budget   : Ownership.Byte_Budget;
      Maximum  : Byte_Count;
      Amount   : Byte_Count) return Results.Result
   is
   begin
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            (Has_Source => True, Source => Info.Offset,
             Block => Arithmetic.Block_For (Info.Kind),
             Extension_Label => Info.Label,
             Expected => Maximum,
             Actual => Ownership.Attempted_Total (Budget, Amount),
             Limit => Allocation_Byte_Limit,
             others => <>)));
   end Allocation_Error;

   function Ensure_Extension_Capacity
     (Object             : in out Store;
      Required           : Positive;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State;
      Info               : Metadata.Extension_Info) return Results.Result
   is
      New_Capacity : Positive;
      New_Charge : Byte_Count;
      Old_Charge : Byte_Count;
      New_Entries : Extension_Index_Access;
      Allocation : Ownership.Allocation_Outcome;

   begin
      if Object.Capacity >= Required then
         return Results.Success;
      end if;
      New_Capacity := Next_Capacity (Object.Capacity, Required);
      New_Charge := Extension_Index_Charge (New_Capacity);
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Allocation := Ownership.Reserve
           (Ticket, Fault, Maximum_Allocation, New_Charge);
         if Allocation.Status = Ownership.Allocation_Ready then
            begin
               New_Entries := new Extension_Index_Array (1 .. New_Capacity);
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Allocation);
            end;
         end if;
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error
           (Info, Budget, Maximum_Allocation, New_Charge);
      end if;
      New_Entries.all := [others => null];
      if Object.Entries /= null then
         New_Entries (1 .. Object.Length) := Object.Entries (1 .. Object.Length);
         Old_Charge := Extension_Index_Charge (Object.Capacity);
         Ownership.Release (Budget, Old_Charge);
         Free_Extension_Index (Object.Entries);
      end if;
      Object.Entries := New_Entries;
      Object.Capacity := New_Capacity;
      return Results.Success;
   end Ensure_Extension_Capacity;

   function Ensure_Chunk_Capacity
     (Node               : in out Extension_Node;
      Required           : Positive;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State) return Results.Result
   is
      New_Capacity : Positive;
      New_Charge : Byte_Count;
      Old_Charge : Byte_Count;
      New_Chunks : Chunk_Index_Access;
      Allocation : Ownership.Allocation_Outcome;

   begin
      if Node.Chunk_Capacity >= Required then
         return Results.Success;
      end if;
      New_Capacity := Next_Capacity (Node.Chunk_Capacity, Required);
      New_Charge := Chunk_Index_Charge (New_Capacity);
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Allocation := Ownership.Reserve
           (Ticket, Fault, Maximum_Allocation, New_Charge);
         if Allocation.Status = Ownership.Allocation_Ready then
            begin
               New_Chunks := new Chunk_Index_Array (1 .. New_Capacity);
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Allocation);
            end;
         end if;
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error
           (Node.Info, Budget, Maximum_Allocation, New_Charge);
      end if;
      New_Chunks.all := [others => null];
      if Node.Chunks /= null then
         New_Chunks (1 .. Node.Chunk_Count) := Node.Chunks (1 .. Node.Chunk_Count);
         Old_Charge := Chunk_Index_Charge (Node.Chunk_Capacity);
         Ownership.Release (Budget, Old_Charge);
         Free_Chunk_Index (Node.Chunks);
      end if;
      Node.Chunks := New_Chunks;
      Node.Chunk_Capacity := New_Capacity;
      return Results.Success;
   end Ensure_Chunk_Capacity;

   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Node : Extension_Node_Access;
      Chunk : Payload_Chunk_Access;
   begin
      if Object.Budget_Address /= System.Null_Address
        and then Object.Budget_Address /= Budget'Address
      then
         return False;
      end if;
      for Index in 1 .. Object.Length loop
         Node := Object.Entries (Index);
         for Chunk_Index in 1 .. Node.Chunk_Count loop
            Chunk := Node.Chunks (Chunk_Index);
            Ownership.Release (Budget, Chunk_Charge);
            Free_Chunk (Chunk);
         end loop;
         if Node.Chunks /= null then
            Ownership.Release
              (Budget, Chunk_Index_Charge (Node.Chunk_Capacity));
            Free_Chunk_Index (Node.Chunks);
         end if;
         Ownership.Release (Budget, Node_Charge);
         Free_Node (Node);
      end loop;
      if Object.Entries /= null then
         Ownership.Release
           (Budget, Extension_Index_Charge (Object.Capacity));
         Free_Extension_Index (Object.Entries);
      end if;
      Object.Length := 0;
      Object.Capacity := 0;
      Object.Retained_Bytes := 0;
      Object.Pending_Index := 0;
      Object.Budget_Address := System.Null_Address;
      return True;
   end Release;

   function Start
     (Object             : in out Store;
      Retention          : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State;
      Info               : Metadata.Extension_Info) return Results.Result
   is
      Outcome : Results.Result;
      Node : Extension_Node_Access;
      Allocation : Ownership.Allocation_Outcome;

   begin
      if Object.Pending_Index /= 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Has_Source => True, Source => Info.Offset,
                Block => Arithmetic.Block_For (Info.Kind),
                Extension_Label => Info.Label,
                others => <>)));
      elsif not Arithmetic.Should_Retain (Retention, Info.Kind) then
         return Results.Success;
      elsif Object.Budget_Address /= System.Null_Address
        and then Object.Budget_Address /= Budget'Address
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Has_Source => True, Source => Info.Offset,
                Block => Arithmetic.Block_For (Info.Kind),
                Extension_Label => Info.Label,
                others => <>)));
      end if;
      Outcome := Ensure_Extension_Capacity
        (Object,
         Object.Length + 1,
         Maximum_Allocation,
         Budget,
         Fault,
         Info);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Object.Budget_Address := Budget'Address;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Allocation := Ownership.Reserve
           (Ticket, Fault, Maximum_Allocation, Node_Charge);
         if Allocation.Status = Ownership.Allocation_Ready then
            begin
               Node := new Extension_Node'(Info => Info, others => <>);
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Allocation);
            end;
         end if;
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error
           (Info, Budget, Maximum_Allocation, Node_Charge);
      end if;
      Object.Length := Object.Length + 1;
      Object.Entries (Object.Length) := Node;
      Object.Pending_Index := Object.Length;
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
      Outcome : Results.Result;
      Chunk : Payload_Chunk_Access;
      Node : Extension_Node_Access;
      Allocation : Ownership.Allocation_Outcome;

   begin
      if Object.Pending_Index = 0 or else Data'Length = 0 then
         return Results.Success;
      elsif Object.Budget_Address /= Budget'Address then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Node := Object.Entries (Object.Pending_Index);
      if Data'Length > 255 then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Has_Source => True,
                Source => Node.Info.Offset,
                Block => Arithmetic.Block_For (Node.Info.Kind),
                Extension_Label => Node.Info.Label,
                others => <>)));
      elsif not Arithmetic.Can_Append
        (Object.Retained_Bytes, Maximum_Retained, Data'Length)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => True, Source => Node.Info.Offset,
                Block => Arithmetic.Block_For (Node.Info.Kind),
                Extension_Label => Node.Info.Label,
                Expected => Maximum_Retained,
                Actual => Budget_Arithmetic.Charge
                  (Object.Retained_Bytes,
                   Byte_Count'Last,
                   Byte_Count (Data'Length)).Attempted,
                Limit => Retained_Metadata_Byte_Limit,
                others => <>)));
      end if;
      Outcome := Ensure_Chunk_Capacity
        (Node.all,
         Node.Chunk_Count + 1,
         Maximum_Allocation,
         Budget,
         Fault);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      declare
         Ticket : Ownership.Reservation (Budget'Access);
      begin
         Allocation := Ownership.Reserve
           (Ticket, Fault, Maximum_Allocation, Chunk_Charge);
         if Allocation.Status = Ownership.Allocation_Ready then
            begin
               Chunk := new Payload_Chunk;
               Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Ownership.Cancel (Ticket, Allocation);
            end;
         end if;
      end;
      if Allocation.Status /= Ownership.Allocation_Ready then
         return Allocation_Error
           (Node.Info, Budget, Maximum_Allocation, Chunk_Charge);
      end if;
      Chunk.Length := Data'Length;
      for I in 0 .. Data'Length - 1 loop
         Chunk.Data (Chunk.Data'First + I) := Data (Data'First + I);
      end loop;
      Node.Chunk_Count := Node.Chunk_Count + 1;
      Node.Chunks (Node.Chunk_Count) := Chunk;
      Object.Retained_Bytes := Arithmetic.Appended_Length
        (Object.Retained_Bytes, Maximum_Retained, Data'Length);
      return Results.Success;
   end Append;

   procedure Finish
     (Object : in out Store;
      Info   : Metadata.Extension_Info)
   is
   begin
      if Object.Pending_Index /= 0 then
         Object.Entries (Object.Pending_Index).Info := Info;
      end if;
      Object.Pending_Index := 0;
   end Finish;

   function Find
     (Object : Store;
      Index  : Positive) return Extension_Node_Access
   is
   begin
      if Index > Object.Length then
         return null;
      end if;
      return Object.Entries (Index);
   end Find;

   function Count (Object : Store) return Natural is (Object.Length);

   function Is_Released (Object : Store) return Boolean is
     (Object.Entries = null
      and then Object.Length = 0
      and then Object.Capacity = 0
      and then Object.Retained_Bytes = 0
      and then Object.Pending_Index = 0
      and then Object.Budget_Address = System.Null_Address);

   function Info_At
     (Object : Store;
      Index  : Positive;
      Info   : out Metadata.Extension_Info) return Results.Result
   is
      Node : constant Extension_Node_Access := Find (Object, Index);
   begin
      Info := (others => <>);
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
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
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Byte_Count (Target'Length) < Node.Info.Payload_Length then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Node.Info.Payload_Length,
                Actual => Byte_Count (Target'Length),
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      for Chunk_Index in 1 .. Node.Chunk_Count loop
         declare
            Chunk : constant Payload_Chunk_Access := Node.Chunks (Chunk_Index);
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
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Count := Node.Chunk_Count;
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
      if Node = null or else Chunk_Index > Node.Chunk_Count then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Chunk := Node.Chunks (Chunk_Index);
      if Target'Length < Chunk.Length then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Chunk.Length),
                Actual => Byte_Count (Target'Length),
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      for I in 0 .. Chunk.Length - 1 loop
         Target (Target'First + I) := Chunk.Data (Chunk.Data'First + I);
      end loop;
      Count := Byte_Count (Chunk.Length);
      return Results.Success;
   end Copy_Chunk;
end Giflib.Internal.Metadata_Store;
