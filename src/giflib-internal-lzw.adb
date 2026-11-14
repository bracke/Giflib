with Giflib.Internal.LZW.Decoding_Machine;

package body Giflib.Internal.LZW is
   package Workspace_Results is new Workspace_Ownership.Result_Operations
     (Results.Result);

   function Ensure
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome is
     (Workspace_Ownership.Ensure (Object.Owner, Budget, Fault, Maximum));

   function Release
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget)
      return Cleanup.Cleanup_Outcome is
     (Workspace_Ownership.Release (Object.Owner, Budget));

   function Is_Allocated (Object : Workspace_Handle) return Boolean is
     (Workspace_Ownership.Is_Allocated (Object.Owner));

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result is
     (Decoding_Machine.Decode
        (Context, Object, Blocks_Reader, Output, Decoded_Count, Parameters));

   function Decode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result
   is
      function Run (Value : in out Workspace) return Results.Result is
        (Decode
           (Value, Object, Blocks_Reader, Output, Decoded_Count, Parameters));
   begin
      return Workspace_Results.Update (Context.Owner, Run'Access);
   end Decode;
end Giflib.Internal.LZW;
