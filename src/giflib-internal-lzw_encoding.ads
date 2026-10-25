with Giflib.Internal.Ownership;
with Giflib.Internal.Interlacing;
with Giflib.Internal.Cleanup;
with Giflib.Results;
with Giflib.Streams;
private with Giflib.Internal.LZW_Encoder_Dictionary;
private with Giflib.Internal.Owned_Objects;

package Giflib.Internal.LZW_Encoding is
   pragma Preelaborate;

   type Workspace_Handle is limited private;

   type Encode_Parameters is record
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout;
   end record;

   type Encode_Statistics is record
      Compressed_Bytes : Byte_Count := 0;
      Wire_Bytes : Byte_Count := 0;
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
   function Encode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Parameters : Encode_Parameters;
      Statistics : out Encode_Statistics) return Results.Result
     with Pre => Is_Allocated (Context);
private
   type Workspace is limited record
      Dictionary : LZW_Encoder_Dictionary.Dictionary;
   end record;

   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Parameters : Encode_Parameters;
      Statistics : out Encode_Statistics) return Results.Result;

   package Workspace_Ownership is new Owned_Objects
     (Workspace, Element_Operations_Are_No_Throw => True);
   type Workspace_Handle is limited record
      Owner : Workspace_Ownership.Handle;
   end record;
end Giflib.Internal.LZW_Encoding;
