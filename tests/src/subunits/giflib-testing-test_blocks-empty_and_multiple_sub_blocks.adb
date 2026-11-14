separate (Giflib.Testing.Test_Blocks)
procedure Empty_And_Multiple_Sub_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Empty_Input : aliased constant Giflib.Streams.Byte_Array := [0];
   Input : aliased constant Giflib.Streams.Byte_Array := [2, 10, 11, 1, 12, 0];
   Source : Giflib.Streams.Memory_Source (Empty_Input'Access);
   Input_Source : Giflib.Streams.Memory_Source (Input'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Buffer : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
   Count : Giflib.Byte_Count;
   At_End : Boolean;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 10, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
   Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Source, Buffer, Count, At_End);
   Assert (Giflib.Results.Succeeded (Outcome), "empty sub-block chain failed");
   Assert (Count = 0 and then At_End and then Giflib.Internal.Blocks.Finished (Reader),
           "empty sub-block chain has wrong state");

   Giflib.Streams.Open (Input_Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 3, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
   Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Input_Source, Buffer, Count, At_End);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 2, "first sub-block failed");
   Assert (Buffer (1 .. 2) = [10, 11], "first sub-block data is wrong");
   Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Input_Source, Buffer, Count, At_End);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 1, "second sub-block failed");
   Assert (Buffer (1) = 12, "second sub-block data is wrong");
   Outcome := Giflib.Internal.Blocks.Read_Data (Reader, Input_Source, Buffer, Count, At_End);
   Assert (Giflib.Results.Succeeded (Outcome) and then Count = 0 and then At_End,
           "sub-block terminator failed");
   Assert (Giflib.Internal.Blocks.Total_Bytes (Reader) = 3, "sub-block byte count is wrong");
end Empty_And_Multiple_Sub_Blocks;
