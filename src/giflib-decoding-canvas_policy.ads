private package Giflib.Decoding.Canvas_Policy with Preelaborate is
   function Setup_Canvas
     (Object : in out Decoder; Header : Header_Info) return Results.Result;
   function Fill_Background
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result;
end Giflib.Decoding.Canvas_Policy;
