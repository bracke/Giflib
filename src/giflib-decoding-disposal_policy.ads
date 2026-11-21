private package Giflib.Decoding.Disposal_Policy with Preelaborate is
   function Apply_Previous (Object : in out Decoder) return Results.Result;
   function Save_Snapshot
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result;
end Giflib.Decoding.Disposal_Policy;
