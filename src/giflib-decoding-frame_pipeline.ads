private package Giflib.Decoding.Frame_Pipeline
  with Preelaborate
is
   function Prepare (Object : in out Decoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Prepare'Result)
        then Object.Pending_Frame.Present);

   function Finish
     (Object : in out Decoder;
      Info : out Frame_Info) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present,
          Post =>
            (if Results.Succeeded (Finish'Result)
             then Object.Current_State = Header_Ready
               and then not Object.Pending_Frame.Present);

   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result
     with Post =>
       (if Results.Succeeded (Start_Decode'Result)
        then Object.Current_State = Decoding_Frame
          and then Object.Pending_Frame.Present
          and then Internal.Decoder_Storage.LZW_Allocated
            (Object.Resources));

   function Start_Skip (Object : in out Decoder) return Results.Result
     with Post =>
       (if Results.Succeeded (Start_Skip'Result)
        then Object.Current_State = Decoding_Frame
          and then Object.Pending_Frame.Present);

   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources);

   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present
                 and then Internal.Decoder_Storage.LZW_Allocated
                   (Object.Resources);

   function Skip_Data (Object : in out Decoder) return Results.Result
     with Pre => Object.Current_State = Decoding_Frame
                 and then Object.Pending_Frame.Present;
end Giflib.Decoding.Frame_Pipeline;
