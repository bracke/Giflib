separate (Giflib.Decoding.Extensions)
function Read_Plain_Text
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   Size_Byte : Byte;
   Fixed : Streams.Byte_Array (1 .. 12);
   First_Data : Streams.Byte_Array (1 .. 255);
   First_Length : Natural;
   Outcome : Results.Result;
begin
   Outcome := Internal.Bytes.Read_Byte
     (Object.Input.all, Size_Byte, Plain_Text_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   elsif Size_Byte /= 12 then
      declare
         Prior : constant Streams.Source_Position_Result :=
           Streams.Position (Object.Input.all, 1);
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Has_Source => Prior.Available,
                Source => Prior.Value,
                Block => Plain_Text_Extension_Block,
                Extension_Label => Info.Label,
                Expected => 12,
                Actual => Byte_Count (Size_Byte),
                others => <>)));
      end;
   end if;

   Outcome := Check_Fixed_Payload
     (Object, Info, 12, Plain_Text_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Streams.Read_Exact (Object.Input.all, Fixed);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   end if;
   Info.Has_Plain_Text_Header := True;
   Info.Plain_Text :=
     (Grid_Left =>
        Internal.Extension_Arithmetic.Decode_U16_LE (Fixed (1), Fixed (2)),
      Grid_Top =>
        Internal.Extension_Arithmetic.Decode_U16_LE (Fixed (3), Fixed (4)),
      Grid_Width =>
        Internal.Extension_Arithmetic.Decode_U16_LE (Fixed (5), Fixed (6)),
      Grid_Height =>
        Internal.Extension_Arithmetic.Decode_U16_LE (Fixed (7), Fixed (8)),
      Cell_Width => Fixed (9),
      Cell_Height => Fixed (10),
      Foreground_Index => Palette_Index (Fixed (11)),
      Background_Index => Palette_Index (Fixed (12)));
   Info.Payload_Length := 12;
   Info.Sub_Block_Count := 1;
   Outcome := Start_Retention (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Retain_Chunk (Object, Fixed);
   end if;
   if Results.Succeeded (Outcome) then
      Outcome := Read_Sub_Blocks
        (Object, Info, First_Data, First_Length);
   end if;
   if Results.Succeeded (Outcome) then
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
   end if;
   return Outcome;
end Read_Plain_Text;
