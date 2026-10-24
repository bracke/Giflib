with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Internal.Ownership;
with System;

package Giflib.Internal.Metadata_Store is
   pragma Preelaborate;

   type Store is limited private;

   function Release
     (Object : in out Store;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;

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

   procedure Finish
     (Object : in out Store;
      Info   : Metadata.Extension_Info);

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
   type Payload_Chunk_Access is access Payload_Chunk;
   type Chunk_Index_Array is array (Positive range <>) of Payload_Chunk_Access;
   type Chunk_Index_Access is access Chunk_Index_Array;

   type Extension_Node is record
      Info : Metadata.Extension_Info;
      Chunks : Chunk_Index_Access := null;
      Chunk_Count : Natural := 0;
      Chunk_Capacity : Natural := 0;
   end record;
   type Extension_Node_Access is access Extension_Node;
   type Extension_Index_Array is array (Positive range <>) of Extension_Node_Access;
   type Extension_Index_Access is access Extension_Index_Array;

   type Store is limited record
      Entries : Extension_Index_Access := null;
      Length : Natural := 0;
      Capacity : Natural := 0;
      Retained_Bytes : Byte_Count := 0;
      Pending_Index : Natural := 0;
      Budget_Address : System.Address := System.Null_Address;
   end record;
end Giflib.Internal.Metadata_Store;
