package Giflib.Capabilities is
   pragma Pure;

   Foundation_API : constant Boolean := True;
   Memory_Streams : constant Boolean := True;
   Container_Decoding : constant Boolean := True;
   Indexed_Decoding : constant Boolean := True;
   Composited_Decoding : constant Boolean := True;
   Indexed_Encoding : constant Boolean := True;
   Animation_Encoding : constant Boolean := True;
   Truecolor_Encoding : constant Boolean := True;
   Quantization : constant Boolean := True;
   Frame_Optimization : constant Boolean := True;
end Giflib.Capabilities;
