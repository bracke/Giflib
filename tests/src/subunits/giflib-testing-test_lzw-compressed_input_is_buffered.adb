separate (Giflib.Testing.Test_LZW)
procedure Compressed_Input_Is_Buffered
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Item_Count : constant Positive := 1_024;
   Input : aliased constant Giflib.Streams.Byte_Array :=
     Literal_Stream (Item_Count);
   Source : Counting_Source (Input'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. Item_Count);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader,
      Giflib.Byte_Count (Input'Length),
      Giflib.Compressed_Byte_Limit,
      Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output, Count, 100_000);
   Assert (Giflib.Results.Succeeded (Outcome),
           "buffered LZW fixture failed");
   Assert (Count = Giflib.Byte_Count (Item_Count)
           and then Source.Read_Calls < Input'Length / 8,
           "LZW decoder reverted to per-byte source reads");
end Compressed_Input_Is_Buffered;

