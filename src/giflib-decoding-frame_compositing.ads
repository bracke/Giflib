private package Giflib.Decoding.Frame_Compositing
  with Preelaborate
is
   function Setup_Canvas
     (Object : in out Decoder;
      Header : Header_Info) return Results.Result;
   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources);
end Giflib.Decoding.Frame_Compositing;
