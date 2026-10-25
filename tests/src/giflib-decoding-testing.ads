package Giflib.Decoding.Testing is
   function Allocated_Bytes (Object : Decoder) return Byte_Count;

   procedure Inject_Storage_Error_After
     (Object : in out Decoder;
      Successful_Allocations : Natural := 0);

   procedure Disable_Failure_Injection (Object : in out Decoder);

   procedure Corrupt_Allocation_Budget (Object : in out Decoder);
   function Resources_Released (Object : Decoder) return Boolean;
end Giflib.Decoding.Testing;
