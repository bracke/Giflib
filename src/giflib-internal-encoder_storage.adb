with Giflib.Internal.Resource_Cleanup;

package body Giflib.Internal.Encoder_Storage is
   function Ensure_Truecolor_Pixels
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Required : Byte_Count;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (Owned_Buffers.Ensure
         (Object.Truecolor_Buffer, Object.Allocation_Budget,
          Fault, Required, Maximum));
   function Ensure_LZW
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is (LZW_Encoding.Ensure
         (Object.LZW_Data, Object.Allocation_Budget, Fault, Maximum));
   function Truecolor_Allocated (Object : Resources) return Boolean is
     (Owned_Buffers.Is_Allocated (Object.Truecolor_Buffer));
   function Truecolor_Length (Object : Resources) return Byte_Count is
     (Owned_Buffers.Length (Object.Truecolor_Buffer));
   function LZW_Allocated (Object : Resources) return Boolean is
     (LZW_Encoding.Is_Allocated (Object.LZW_Data));
   function Cleanup_Succeeded (Object : Resources) return Boolean is
     (not Object.Cleanup_Failed
      and then Is_Released (Object)
      and then Allocated_Bytes (Object) = 0);
   function Is_Released (Object : Resources) return Boolean is
     (not Owned_Buffers.Is_Allocated (Object.Truecolor_Buffer)
      and then not LZW_Encoding.Is_Allocated (Object.LZW_Data)
      and then Quantization.Allocated_Bytes (Object.Quantizer_Data) = 0);
   function Allocated_Bytes (Object : Resources) return Byte_Count is
     (Ownership.Used (Object.Allocation_Budget));
   function Quantizer_Bytes (Object : Resources) return Byte_Count is
     (Quantization.Allocated_Bytes (Object.Quantizer_Data));

   procedure Release (Object : in out Resources) is
      Status : Resource_Cleanup.Guard
        (Object.Allocation_Budget'Access, Object.Cleanup_Failed'Access);
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
      procedure Try_Buffer is new Resource_Cleanup.Attempt (Release_Buffer);
      procedure Try_LZW is new Resource_Cleanup.Attempt (Release_LZW);
      procedure Try_Quantizer is new Resource_Cleanup.Attempt
        (Release_Quantizer);
   begin
      Try_Buffer (Status);
      Try_LZW (Status);
      Try_Quantizer (Status);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Encoder_Storage;
