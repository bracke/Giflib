with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Decoder_Reader;
with Giflib.Internal.Work_Budgets;

private package Giflib.Internal.LZW.Decoding_Machine
  with Preelaborate
is
   type Decoder_State (Maximum_Work : Byte_Count) is record
      Minimum : LZW_Arithmetic.Minimum_Code_Size := LZW_Arithmetic.Minimum_Code_Size'First;
      Clear_Code : LZW_Arithmetic.Clear_Code_Value := LZW_Arithmetic.Clear_Code_Value'First;
      End_Code : LZW_Arithmetic.Code_Value := 0;
      First_New_Code : LZW_Arithmetic.Next_Code_Value := LZW_Arithmetic.Next_Code_Value'First;
      Next_Free_Code : LZW_Arithmetic.Next_Code_Value := LZW_Arithmetic.Next_Code_Value'First;
      Code_Width : LZW_Arithmetic.Active_Code_Width := LZW_Arithmetic.Active_Code_Width'First;
      Old_Code : LZW_Arithmetic.Code_Value := 0;
      Have_Old_Code : Boolean := False;
      Initial_Clear_Seen : Boolean := False;
      First_Character : Byte := 0;
      Output_Position : Natural := 0;
      Work : Work_Budgets.Meter (Maximum_Work);
      Reader : LZW_Decoder_Reader.Code_Reader;
   end record;

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result;
end Giflib.Internal.LZW.Decoding_Machine;
