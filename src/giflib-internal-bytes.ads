with Interfaces;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Bytes is
   pragma Preelaborate;

   function Read_Byte
     (Object : in out Streams.Source'Class;
      Value : out Byte;
      Block : Block_Kind := No_Block) return Results.Result;

   function Read_U16_LE
     (Object : in out Streams.Source'Class;
      Value : out Interfaces.Unsigned_16;
      Block : Block_Kind := No_Block) return Results.Result;

   function Write_Byte
     (Object : in out Streams.Destination'Class;
      Value : Byte;
      Block : Block_Kind := No_Block) return Results.Result;

   function Write_U16_LE
     (Object : in out Streams.Destination'Class;
      Value : Interfaces.Unsigned_16;
      Block : Block_Kind := No_Block) return Results.Result;
end Giflib.Internal.Bytes;
