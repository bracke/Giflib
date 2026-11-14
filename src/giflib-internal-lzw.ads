with Giflib.Internal.Blocks;
with Giflib.Internal.Interlacing;
with Giflib.Internal.Cleanup;
with Giflib.Internal.Ownership;
with Giflib.Results;
with Giflib.Streams;
private with Giflib.Internal.LZW_Decoder_Dictionary;
private with Giflib.Internal.Owned_Objects;

package Giflib.Internal.LZW is
   pragma Preelaborate;

   type Workspace_Handle is limited private;

   type Decode_Parameters is record
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout;
   end record;

   function Ensure
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;
   function Release
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome;
   function Is_Allocated (Object : Workspace_Handle) return Boolean;
   function Decode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result
     with Pre => Is_Allocated (Context);
private
   type Workspace is limited record
      Dictionary : LZW_Decoder_Dictionary.Dictionary;
   end record
     with No_Controlled_Parts => True;

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result;

   package Workspace_Ownership is new Giflib.Internal.Owned_Objects
     (Workspace);
   type Workspace_Handle is limited record
      Owner : Workspace_Ownership.Handle;
   end record;
end Giflib.Internal.LZW;
