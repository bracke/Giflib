separate (Giflib.Testing.Test_LZW)
procedure Decodes_All_Minimum_Code_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. 1);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
begin
   for Minimum in 2 .. 8 loop
      declare
         Clear : constant Natural := 2 ** Minimum;
         Input : aliased constant Giflib.Streams.Byte_Array :=
           Pack ([Clear, Clear - 1, Clear + 1],
                 [Minimum + 1, Minimum + 1, Minimum + 1]);
         Source : Giflib.Streams.Memory_Source (Input'Access);
      begin
         Giflib.Streams.Open (Source);
         Giflib.Internal.Blocks.Initialize
           (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
         Outcome := Giflib.Internal.LZW.Testing.Decode
           (Context, Source, Reader, Giflib.Byte (Minimum), Output, Count, 100);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Output (1) = Giflib.Byte (Clear - 1),
                 "valid minimum code size" & Natural'Image (Minimum) & " failed");
      end;
   end loop;
end Decodes_All_Minimum_Code_Sizes;

