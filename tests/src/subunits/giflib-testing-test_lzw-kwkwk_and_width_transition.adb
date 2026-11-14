separate (Giflib.Testing.Test_LZW)
procedure KwKwK_And_Width_Transition (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   KwKwK : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 6, 5], [3, 3, 3, 3]);
   Wider : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 2, 3, 5], [3, 3, 3, 3, 4, 4]);
   Source : Giflib.Streams.Memory_Source (KwKwK'Access);
   Wider_Source : Giflib.Streams.Memory_Source (Wider'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. 4);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output (1 .. 3), Count, 100);
   Assert (Giflib.Results.Succeeded (Outcome) and then Output (1 .. 3) = [0, 0, 0],
           "KwKwK sequence failed");

   Giflib.Streams.Open (Wider_Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Wider_Source, Reader, 2, Output, Count, 100);
   Assert (Giflib.Results.Succeeded (Outcome) and then Output = [0, 1, 2, 3],
           "code-width transition failed");
end KwKwK_And_Width_Transition;

