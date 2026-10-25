with Giflib.Internal.Geometry_Arithmetic;

private package Giflib.Decoding.Frame_Pipeline
  with Preelaborate
is
   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result
     with Post =>
       (if Results.Succeeded (Start_Decode'Result)
        then Object.Current_State = Decoding_Frame
          and then Object.Has_Pending_Frame
          and then Internal.Decoder_Storage.LZW_Allocated
            (Object.Resources));

   function Start_Skip (Object : in out Decoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Start_Skip'Result)
        then Object.Current_State = Decoding_Frame
          and then Object.Has_Pending_Frame);

   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Has_Pending_Frame
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources);

   function Decode_Scratch
     (Object : in out Decoder;
      Pixel_Bytes : Byte_Count) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Has_Pending_Frame
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources)
                 and then Internal.Decoder_Storage.Frame_Scratch_Allocated
                   (Object.Resources)
                 and then Pixel_Bytes = Internal.Geometry_Arithmetic.Area
                   (Object.Pending_Frame.Width, Object.Pending_Frame.Height)
                 and then Pixel_Bytes <= Byte_Count (Natural'Last)
                 and then Internal.Decoder_Storage.Frame_Scratch_Length
                   (Object.Resources) >= Pixel_Bytes;
end Giflib.Decoding.Frame_Pipeline;
