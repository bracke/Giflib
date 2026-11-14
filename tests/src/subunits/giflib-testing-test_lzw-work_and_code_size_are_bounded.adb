separate (Giflib.Testing.Test_LZW)
procedure Work_And_Code_Size_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. 2);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 1, Output, Count, 100);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Minimum_Code_Size,
           "invalid minimum code size was accepted");

   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output, Count, 1);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "LZW work limit was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.LZW_Work_Limit,
           "LZW work failure lost limit context");
end Work_And_Code_Size_Are_Bounded;

