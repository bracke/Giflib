with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Internal.Owned_Element_Vectors;
with Giflib.Internal.Ownership;

package Giflib.Internal.Metadata_Store is
   pragma Preelaborate;

   type Store is limited private;

   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   --  A foreign Budget returns False without changing Object, so cleanup can
   --  be retried with the owning ledger. A same-ledger bookkeeping failure
   --  still frees and clears Object and is recorded by the ledger.

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
   end record;
   function Release_Payload
     (Element : in out Payload_Chunk;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   package Payload_Chunks is new Owned_Element_Vectors
     (Element_Type => Payload_Chunk,
      Release_Contents => Release_Payload);

   type Extension_Node is limited record
      Info : Metadata.Extension_Info;
      Chunks : Payload_Chunks.Handle;
      Retained_Length : Byte_Count := 0;
   end record;
   function Release_Node
     (Element : in out Extension_Node;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   package Extension_Nodes is new Owned_Element_Vectors
     (Element_Type => Extension_Node,
      Release_Contents => Release_Node);

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
      Retained_Bytes : Byte_Count := 0;
      Pending : Pending_Extension;
      Owner : Ownership.Budget_Owner;
   end record;
end Giflib.Internal.Metadata_Store;
