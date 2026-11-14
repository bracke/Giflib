separate (Giflib.Testing.Test_Image_Data)
procedure Decodes_Into_Caller_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   --  Minimum size 2; codes Clear, 0, 1, End packed LSB-first.
   Input : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#, 16#0A#, 0];
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Context : Giflib.Internal.LZW.Workspace_Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Output : Giflib.Streams.Byte_Array (1 .. 2) := [99, 99];
   Pixels : Giflib.Pixel_Count := 0;
   Compressed : Giflib.Byte_Count := 0;
   Outcome : Giflib.Results.Result;
begin
   Prepare (Context, Budget, Fault);
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context,
      Source,
      1,
      2,
      False,
      Two_Color_Palette,
      Giflib.Limits.Default_Limits,
      Pixels,
      Compressed,
      Output,
      Frame => 2);
   Assert (Giflib.Results.Succeeded (Outcome), "valid image data failed");
   Assert (Output = [0, 1], "caller-owned output is wrong");
   Assert (Pixels = 2, "decoded pixel accounting is wrong");
   Assert (Compressed = 2, "compressed byte accounting is wrong");
   Assert (Giflib.Internal.Cleanup.Succeeded
             (Giflib.Internal.LZW.Release (Context, Budget)),
           "image-data LZW workspace ledger mismatch");
end Decodes_Into_Caller_Buffer;
