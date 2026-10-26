separate (Giflib.Testing.Test_LZW)
procedure Decoder_Components_Honor_Boundaries
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   --  One sub-block containing the clear code (4) in a three-bit stream.
   Input : aliased constant Giflib.Streams.Byte_Array := [1, 4, 0];
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Blocks_Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Reader : Giflib.Internal.LZW_Decoder_Reader.Code_Reader;
   Work : Giflib.Internal.Work_Budgets.Meter (100);
   Output : Giflib.Streams.Byte_Array (1 .. 1) := [0];
   Position : Natural := 0;
   Code : Giflib.Internal.LZW_Arithmetic.Code_Value;
   Outcome : Giflib.Results.Result;
   Dictionary : Giflib.Internal.LZW_Decoder_Dictionary.Dictionary;
begin
   Assert
     (not Giflib.Internal.LZW_Decoder_Dictionary.Is_Initialized
        (Dictionary),
      "decoder dictionary unexpectedly started initialized");
   Giflib.Internal.LZW_Decoder_Dictionary.Reset (Dictionary, 6);
   Giflib.Internal.LZW_Decoder_Dictionary.Set_Entry
     (Dictionary, 6, 0, 1);
   Assert
     (Giflib.Internal.LZW_Decoder_Dictionary.Is_Defined (Dictionary, 6)
      and then Giflib.Internal.LZW_Decoder_Dictionary.Prefix_At
        (Dictionary, 6) = 0
      and then Giflib.Internal.LZW_Decoder_Dictionary.Suffix_At
        (Dictionary, 6) = 1,
      "decoder dictionary did not own its definition boundary");
   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Blocks_Reader, 100, Giflib.Compressed_Byte_Limit,
      Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW_Decoder_Reader.Next_Code
     (Reader, Source, Blocks_Reader, Work,
      (Code_Width => 3, Frame => 2,
       Output_Length => Output'Length,
       Output_Position => Position),
      Code);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Code = 4
      and then Giflib.Internal.LZW_Decoder_Reader.Ordinal (Reader) = 1,
      "decoder reader lost its code or ordinal boundary");
   Outcome := Giflib.Internal.LZW_Decoder_Output.Emit
     (Source, Output, Position, 1, Work,
      (Code_Ordinal =>
         Giflib.Internal.LZW_Decoder_Reader.Ordinal (Reader),
       Maximum_Index => 1,
       Layout => Giflib.Internal.Interlacing.Sequential_Layout,
       Code_Width => 3,
       Frame => 2));
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Position = 1
      and then Output = [1],
      "decoder output did not place a valid literal");

   Outcome := Giflib.Internal.LZW_Decoder_Output.Emit
     (Source, Output, Position, 0, Work,
      (Code_Ordinal =>
         Giflib.Internal.LZW_Decoder_Reader.Ordinal (Reader),
       Maximum_Index => 1,
       Layout => Giflib.Internal.Interlacing.Sequential_Layout,
       Code_Width => 3,
       Frame => 2));
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
      "decoder output accepted a literal beyond its target");
end Decoder_Components_Honor_Boundaries;
