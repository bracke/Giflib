separate (Giflib.Testing.Test_Blocks)
procedure Full_Size_Block_Is_Drained (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : aliased constant Giflib.Streams.Byte_Array := Full_Block_Stream;
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 7);
   Giflib.Internal.Blocks.Initialize
     (Reader, 255, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.Blocks.Drain (Reader, Source);
   Assert (Giflib.Results.Succeeded (Outcome), "255-byte sub-block did not drain");
   Assert (Giflib.Internal.Blocks.Total_Bytes (Reader) = 255, "255-byte count is wrong");
   Assert (Source.Offset = 257 and then Giflib.Internal.Blocks.Finished (Reader),
           "255-byte stream boundary is wrong");
end Full_Size_Block_Is_Drained;
