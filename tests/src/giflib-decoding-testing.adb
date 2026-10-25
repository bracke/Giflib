with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.LZW;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Owned_Buffers;

package body Giflib.Decoding.Testing is
   function Allocated_Bytes (Object : Decoder) return Byte_Count is
     (Internal.Ownership.Used (Object.Resources.Allocation_Budget));

   procedure Inject_Storage_Error_After
     (Object : in out Decoder;
      Successful_Allocations : Natural := 0)
   is
   begin
      Internal.Ownership.Testing.Arm
        (Object.Allocation_Fault, Successful_Allocations);
   end Inject_Storage_Error_After;

   procedure Disable_Failure_Injection (Object : in out Decoder) is
   begin
      Internal.Ownership.Testing.Disable (Object.Allocation_Fault);
   end Disable_Failure_Injection;

   procedure Corrupt_Allocation_Budget (Object : in out Decoder) is
   begin
      Internal.Ownership.Testing.Set_Used
        (Object.Resources.Allocation_Budget, 0);
   end Corrupt_Allocation_Budget;

   function Resources_Released (Object : Decoder) return Boolean is
     (Internal.Metadata_Store.Is_Released (Object.Resources.Metadata_Storage)
      and then not Internal.Owned_Buffers.Is_Allocated (Object.Resources.Canvas)
      and then not Internal.Owned_Buffers.Is_Allocated (Object.Resources.Snapshot)
      and then not Internal.Owned_Buffers.Is_Allocated
        (Object.Resources.Frame_Scratch)
      and then not Internal.LZW.Is_Allocated (Object.Resources.LZW_Workspace));
end Giflib.Decoding.Testing;
