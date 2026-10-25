with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Encoder_Storage is
   function Truecolor_Pixels
     (Object : aliased in out Resources) return not null access Owned_Buffers.Handle is
     (Object.Truecolor_Buffer'Access);
   function Budget
     (Object : aliased in out Resources) return not null access Ownership.Byte_Budget is
     (Object.Allocation_Budget'Access);
   function Quantizer
     (Object : aliased in out Resources) return not null access Quantization.Workspace is
     (Object.Quantizer_Data'Access);
   function LZW_Workspace
     (Object : aliased in out Resources)
      return not null access LZW_Encoding.Workspace_Handle is
     (Object.LZW_Data'Access);
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (not Object.Cleanup_Failed);
   function Is_Released (Object : Resources) return Boolean is
     (not Owned_Buffers.Is_Allocated (Object.Truecolor_Buffer)
      and then not LZW_Encoding.Is_Allocated (Object.LZW_Data)
      and then Quantization.Allocated_Bytes (Object.Quantizer_Data) = 0);
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));
   function Quantizer_Bytes (Object : Resources) return Byte_Count is
     (Quantization.Allocated_Bytes (Object.Quantizer_Data));
   function Quantizer_Cleanup_Succeeded (Object : Resources) return Boolean is
     (Quantization.Cleanup_Succeeded (Object.Quantizer_Data));

   procedure Release (Object : in out Resources) is
      function Release_Buffer return Boolean is
        (Owned_Buffers.Release
           (Object.Truecolor_Buffer, Object.Allocation_Budget));
      function Release_LZW return Boolean is
        (LZW_Encoding.Release
           (Object.LZW_Data, Object.Allocation_Budget));
      function Release_Quantizer return Boolean is
      begin
         Quantization.Finalize (Object.Quantizer_Data);
         return Quantization.Cleanup_Succeeded (Object.Quantizer_Data);
      end Release_Quantizer;
      procedure Release_All is new Resource_Cleanup.Release_Three
        (Release_Buffer, Release_LZW, Release_Quantizer);
   begin
      Release_All (Object.Allocation_Budget, Object.Cleanup_Failed);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Encoder_Storage;
