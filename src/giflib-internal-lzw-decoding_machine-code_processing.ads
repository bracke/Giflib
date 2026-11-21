with Giflib.Errors;
with Giflib.Internal.LZW_Arithmetic;

private package Giflib.Internal.LZW.Decoding_Machine.Code_Processing
  with Preelaborate
is
   procedure Initialize
     (Context : in out Workspace;
      State : in out Decoder_State;
      Minimum_Code_Size : Byte;
      Maximum_Index : Byte);

   type Process_Status is
     (Process_Continue, Process_Finished, Process_Failed);

   function Failure
     (Object : Streams.Source'Class;
      Output_Length : Natural;
      Frame : Frame_Ordinal;
      State : in out Decoder_State;
      Code : Errors.Error_Code;
      Value : LZW_Arithmetic.Code_Value := 0) return Process_Status;

   function Process
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Parameters : Decode_Parameters;
      State : in out Decoder_State;
      Code : LZW_Arithmetic.Code_Value) return Process_Status;
   pragma Inline_Always (Process);
end Giflib.Internal.LZW.Decoding_Machine.Code_Processing;
