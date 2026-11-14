with Giflib.Encoding.Wire_Output;
with Giflib.Internal.Wire_Format;

package body Giflib.Encoding.Extensions.Emission is
   function Write_Chunk
     (Object : in out Encoder;
      Payload : Streams.Byte_Array;
      Position : in out Natural;
      Length : Positive) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Wire_Output.Write (Object, [1 => Byte (Length)]);
      if Results.Succeeded (Outcome) then
         Outcome := Wire_Output.Write
           (Object,
            Payload
              (Payload'First + Position
               .. Payload'First + Position + Length - 1));
      end if;
      if Results.Succeeded (Outcome) then
         Position := Position + Length;
      end if;
      return Outcome;
   end Write_Chunk;

   function Write_Prefix
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Position : out Natural) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Position := 0;
      Outcome := Wire_Output.Write
        (Object,
         [Internal.Wire_Format.Extension_Introducer,
          Metadata.Label_Of (Descriptor)]);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Fixed_Length > 0 then
         Outcome := Wire_Output.Write (Object, [1 => Byte (Fixed_Length)]);
         if Results.Succeeded (Outcome) then
            Outcome := Wire_Output.Write
              (Object,
               Payload (Payload'First .. Payload'First + Fixed_Length - 1));
         end if;
         Position := Fixed_Length;
      end if;
      return Outcome;
   end Write_Prefix;

   function Emit
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Plan : Chunk_Plan) return Results.Result
   is
      Position : Natural;
      Chunk : Natural;
      Outcome : Results.Result;
   begin
      if Plan.Kind = Automatic_Chunks then
         Outcome := Write_Prefix
           (Object, Descriptor, Payload, Fixed_Length, Position);
         while Results.Succeeded (Outcome)
           and then Position < Payload'Length
         loop
            Chunk := Natural'Min (255, Payload'Length - Position);
            Outcome := Write_Chunk
              (Object, Payload, Position, Positive (Chunk));
         end loop;
      else
         Position := 0;
         Outcome := Wire_Output.Write
           (Object,
            [Internal.Wire_Format.Extension_Introducer,
             Metadata.Label_Of (Descriptor)]);
         for Length of Plan.Lengths loop
            exit when not Results.Succeeded (Outcome);
            Outcome := Write_Chunk (Object, Payload, Position, Length);
         end loop;
      end if;
      return Outcome;
   end Emit;
end Giflib.Encoding.Extensions.Emission;
