with Giflib.Errors;
with Giflib.Internal.LZW_Arithmetic;

private package Giflib.Internal.LZW.Decoding_Machine.Code_Processing
  with Preelaborate
is
   procedure Initialize
     (Context : in out Workspace;
      State : in out Decoder_State;
      Minimum_Code_Size : Byte);

   function Failure
     (Object : Streams.Source'Class;
      Output_Length : Natural;
      Frame : Frame_Ordinal;
      State : Decoder_State;
      Code : Errors.Error_Code;
      Value : LZW_Arithmetic.Code_Value := 0) return Results.Result;

   function Process
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value;
      Finished : out Boolean) return Results.Result;
end Giflib.Internal.LZW.Decoding_Machine.Code_Processing;
