separate (Giflib.Testing.Test_LZW)
procedure Malformed_Codes_And_Sizes_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Forward : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 7, 5], [3, 3, 3, 3]);
   Early_End : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 5], [3, 3, 3]);
   Excess : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
   No_Initial_Clear : aliased constant Giflib.Streams.Byte_Array := Pack ([0, 5], [3, 3]);
   No_End : aliased constant Giflib.Streams.Byte_Array :=
     Pack ([4, 0, 0, 0, 0, 0, 0, 0], [3, 3, 3, 3, 3, 3, 3, 3]);
   Source : Giflib.Streams.Memory_Source (Forward'Access);
   Early_Source : Giflib.Streams.Memory_Source (Early_End'Access);
   Excess_Source : Giflib.Streams.Memory_Source (Excess'Access);
   No_Clear_Source : Giflib.Streams.Memory_Source (No_Initial_Clear'Access);
   No_End_Source : Giflib.Streams.Memory_Source (No_End'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Context : Giflib.Internal.LZW.Testing.Workspace;
   Output : Giflib.Streams.Byte_Array (1 .. 7);
   Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;

   procedure Start (Input : in out Giflib.Streams.Memory_Source) is
   begin
      Giflib.Streams.Open (Input);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   end Start;
begin
   Start (Source);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Source, Reader, 2, Output (1 .. 3), Count, 100);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
           "forward dictionary reference was accepted");

   Start (Early_Source);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Early_Source, Reader, 2, Output (1 .. 2), Count, 100);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
           "early end code was accepted");

   Start (Excess_Source);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, Excess_Source, Reader, 2, Output (1 .. 1), Count, 100);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
           "excess output was accepted");

   Start (No_Clear_Source);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, No_Clear_Source, Reader, 2, Output (1 .. 1), Count, 100);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
           "stream without an initial clear code was accepted");
   Assert
     (Outcome.First_Error.Context.LZW.Present
      and then Outcome.First_Error.Context.Expected = 4
      and then Outcome.First_Error.Context.Actual = 0,
      "missing-initial-clear diagnostic context is wrong");

   Start (No_End_Source);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Context, No_End_Source, Reader, 2, Output, Count, 1_000);
   Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Missing_End_Code,
           "missing end code was accepted");
end Malformed_Codes_And_Sizes_Fail;

