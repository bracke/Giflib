private package Giflib.Encoding.Wire_Output is
   pragma Preelaborate;

   function Write
     (Object : in out Encoder; Data : Streams.Byte_Array)
      return Results.Result;
   function Write_Color_Table
     (Object : in out Encoder; Palette : Palettes.Palette)
      return Results.Result;
end Giflib.Encoding.Wire_Output;
