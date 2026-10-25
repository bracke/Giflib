package body Giflib.Internal.Encoder_Storage is
   procedure Release (Object : in out Resources) is
      Failed : Boolean := False;
      function Release_Buffer return Boolean is
        (Owned_Buffers.Release
           (Object.Truecolor_Pixels, Object.Allocation_Budget));
      function Release_LZW return Boolean is
        (LZW_Encoding.Release
           (Object.LZW_Workspace, Object.Allocation_Budget));
      function Release_Quantizer return Boolean is
      begin
         Quantization.Finalize (Object.Quantizer);
         return Quantization.Cleanup_Succeeded (Object.Quantizer);
      end Release_Quantizer;
      procedure Try_Buffer is new Ownership.Attempt_Release (Release_Buffer);
      procedure Try_LZW is new Ownership.Attempt_Release (Release_LZW);
      procedure Try_Quantizer is new Ownership.Attempt_Release
        (Release_Quantizer);
   begin
      Try_Buffer (Failed);
      Try_LZW (Failed);
      Try_Quantizer (Failed);
      Object.Cleanup_Failed :=
        Object.Cleanup_Failed
        or else Failed
        or else not Ownership.Healthy (Object.Allocation_Budget);
   end Release;

   overriding procedure Finalize (Object : in out Resources) is
   begin
      Release (Object);
   end Finalize;
end Giflib.Internal.Encoder_Storage;
