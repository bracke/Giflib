separate (Giflib.Testing.Test_LZW)
procedure Basic_And_Repeated_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Basic : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
   Repeated : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 4, 1, 5], [3, 3, 3, 3]);
   Source : Giflib.Streams.Memory_Source (Basic'Access);
   Repeated_Source : Giflib.Streams.Memory_Source (Repeated'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. 2);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output, Count, 100);
   Assert (Giflib.Results.Succeeded (Outcome), "basic LZW stream failed");
   Assert (Count = 2 and then Output = [0, 1], "basic LZW output is wrong");
   Giflib.Streams.Open (Repeated_Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Repeated_Source, Reader, 2, Output (1 .. 1), Count, 100);
   Assert (Giflib.Results.Succeeded (Outcome), "repeated clear codes failed");
   Assert (Count = 1 and then Output (1) = 1, "repeated-clear output is wrong");
end Basic_And_Repeated_Clear;
