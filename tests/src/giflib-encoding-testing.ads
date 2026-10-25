package Giflib.Encoding.Testing is
   function Allocated_Bytes (Object : Encoder) return Byte_Count;

   procedure Set_Bytes_Written
     (Object : in out Encoder;
      Value : Byte_Count);

   function Bytes_Written (Object : Encoder) return Byte_Count;
   function Compressed_Bytes_Written (Object : Encoder) return Byte_Count;

   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result;

   procedure Inject_Storage_Error_After
     (Object : in out Encoder;
      Successful_Allocations : Natural := 0);

   procedure Inject_Quantizer_Storage_Error_After
     (Object : in out Encoder;
      Successful_Allocations : Natural := 0);

   procedure Disable_Failure_Injection (Object : in out Encoder);

   procedure Corrupt_Quantizer_Allocation_Budget
     (Object : in out Encoder);

   procedure Corrupt_Allocation_Budget (Object : in out Encoder);
   function Resources_Released (Object : Encoder) return Boolean;

   function Quantizer_Cleanup_Succeeded (Object : Encoder) return Boolean;
end Giflib.Encoding.Testing;
