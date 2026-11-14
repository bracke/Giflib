private package Giflib.Decoding.Output_Validation is
   pragma Preelaborate;

   function Validate
     (Object : Decoder;
      Target_Length : Byte_Count;
      Expected_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result;
   function Deliver
     (Object : in out Decoder;
      Event : out Decode_Event;
      Value : Decode_Event) return Results.Result;
end Giflib.Decoding.Output_Validation;
