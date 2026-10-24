private package Giflib.Decoding.Extensions is
   pragma Preelaborate;

   function Read
     (Object      : in out Decoder;
      Offset      : Source_Offset;
      Label_Value : Byte;
      Info        : out Metadata.Extension_Info) return Results.Result;
end Giflib.Decoding.Extensions;
