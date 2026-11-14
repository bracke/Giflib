separate (Giflib.Testing.Test_LZW)
procedure Dictionary_Full_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Item_Count : constant Positive := 4_093;
   Input : aliased constant Giflib.Streams.Byte_Array := Literal_Stream (Item_Count);
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. Item_Count);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source, Max_Transfer => 3);
   Giflib.Internal.Blocks.Initialize
     (Reader, Giflib.Byte_Count (Input'Length), Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output, Count, 100_000);
   Assert (Giflib.Results.Succeeded (Outcome), "full 12-bit dictionary stream failed");
   Assert (Count = Giflib.Byte_Count (Item_Count), "dictionary-full output count is wrong");
   for I in Output'Range loop
      Assert (Output (I) = Giflib.Byte ((I - 1) mod 4), "dictionary-full literal changed");
   end loop;
end Dictionary_Full_Is_Bounded;

