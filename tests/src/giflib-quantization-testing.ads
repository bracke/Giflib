package Giflib.Quantization.Testing is
   procedure Inject_Storage_Error_After
     (Context : in out Workspace;
      Successful_Allocations : Natural := 0);

   procedure Disable_Failure_Injection (Context : in out Workspace);

   procedure Corrupt_Allocation_Budget (Context : in out Workspace);
end Giflib.Quantization.Testing;
