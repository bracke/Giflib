private package Giflib.Decoding.Frame_Lifecycle
  with Preelaborate
is
   function Prepare (Object : in out Decoder) return Results.Result;
   function Finish
     (Object : in out Decoder;
      Info : out Frame_Info) return Results.Result;
   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result;
   function Start_Skip (Object : in out Decoder) return Results.Result;
end Giflib.Decoding.Frame_Lifecycle;
