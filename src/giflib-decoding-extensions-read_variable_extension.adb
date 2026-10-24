separate (Giflib.Decoding.Extensions)
function Read_Variable_Extension
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   First_Data : Streams.Byte_Array (1 .. 255);
   First_Length : Natural;
   Outcome : Results.Result;
begin
   Outcome := Start_Retention (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Read_Sub_Blocks
        (Object, Info, First_Data, First_Length);
   end if;
   return Outcome;
end Read_Variable_Extension;
