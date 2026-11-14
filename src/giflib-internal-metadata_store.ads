with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Vectors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Cleanup;

package Giflib.Internal.Metadata_Store is
   pragma Preelaborate;

   type Store is limited private;

   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome;
   --  A foreign Budget reports Cleanup_Owner_Mismatch without changing Object,
   --  so cleanup can be retried with the owning ledger. A same-ledger
   --  bookkeeping failure still frees and clears Object and is recorded by the
   --  ledger and the returned cleanup status.

   function Start
     (Object             : in out Store;
      Retention          : Metadata.Retention_Policy;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State;
      Info               : Metadata.Extension_Info) return Results.Result;

   function Append
     (Object             : in out Store;
      Data               : Streams.Byte_Array;
      Maximum_Retained   : Byte_Count;
      Maximum_Allocation : Byte_Count;
      Budget             : aliased in out Ownership.Byte_Budget;
      Fault              : in out Ownership.Fault_State) return Results.Result;

   function Finish
     (Object : in out Store;
      Info   : Metadata.Extension_Info) return Results.Result;

   function Count (Object : Store) return Natural;
   function Is_Released (Object : Store) return Boolean;

   function Info_At
     (Object : Store;
      Index  : Positive;
      Info   : out Metadata.Extension_Info) return Results.Result;

   function Copy_Payload
     (Object : Store;
      Index  : Positive;
      Target : out Streams.Byte_Array;
      Count  : out Byte_Count) return Results.Result;

   function Chunk_Count
     (Object : Store;
      Index  : Positive;
      Count  : out Natural) return Results.Result;

   function Copy_Chunk
     (Object      : Store;
      Index       : Positive;
      Chunk_Index : Positive;
      Target      : out Streams.Byte_Array;
      Count       : out Byte_Count) return Results.Result;

private
   type Payload_Chunk is record
      Length : Natural range 1 .. 255 := 1;
      Data : Streams.Byte_Array (1 .. 255) := [others => 0];
   end record
     with No_Controlled_Parts => True;
   type Payload_Chunk_Array is
     array (Positive range <>) of Payload_Chunk;
   package Payload_Storage is new Giflib.Internal.Owned_Arrays
     (Positive, Payload_Chunk, Payload_Chunk_Array,
      (Length => 1, Data => [others => 0]));
   package Payload_Chunks is new Owned_Vectors
     (Element_Type => Payload_Chunk, Storage => Payload_Storage);

   subtype Retained_Payload_Length is
     Byte_Count range 1 .. Byte_Count'Last;
   type Chunk_Span (Present : Boolean := False) is record
      case Present is
         when True =>
            First : Positive := 1;
            Count : Positive := 1;
            Length : Retained_Payload_Length := 1;
         when False =>
            null;
      end case;
   end record
     with No_Controlled_Parts => True;
   type Extension_Node is record
      Info : Metadata.Extension_Info;
      Span : Chunk_Span;
   end record
     with No_Controlled_Parts => True;
   type Extension_Node_Array is
     array (Positive range <>) of Extension_Node;
   package Extension_Storage is new Giflib.Internal.Owned_Arrays
     (Positive, Extension_Node, Extension_Node_Array,
      (Info =>
         (Kind => Metadata.Unknown_Extension,
          Offset => 0,
          Before_Frame => 0,
          Payload_Length => 0,
          Sub_Block_Count => 0,
          Label => 0),
       Span => (Present => False)));
   package Extension_Nodes is new Owned_Vectors
     (Element_Type => Extension_Node, Storage => Extension_Storage);

   type Transaction_State is (Idle, Ignoring, Building);
   type Pending_Extension (State : Transaction_State := Idle) is record
      case State is
         when Building =>
            Index : Positive := 1;
         when Idle | Ignoring =>
            null;
      end case;
   end record;

   type Store is limited record
      Entries : Extension_Nodes.Handle;
      Chunks : Payload_Chunks.Handle;
      Retained_Bytes : Byte_Count := 0;
      Pending : Pending_Extension;
   end record;
end Giflib.Internal.Metadata_Store;
