separate (Giflib.Decoding.Extensions)
function Read_Graphic_Control
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   Size_Byte : Byte;
   Terminator : Byte;
   Fixed : Streams.Byte_Array (1 .. 4);
   Control : Frames.Graphic_Control;
   Outcome : Results.Result;
begin
   Outcome := Internal.Bytes.Read_Byte
     (Object.Input.all, Size_Byte, Graphic_Control_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   elsif Size_Byte /= 4 then
      declare
         Prior : constant Streams.Source_Position_Result :=
           Streams.Position (Object.Input.all, 1);
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Has_Source => Prior.Available,
                Source => Prior.Value,
                Block => Graphic_Control_Extension_Block,
                Extension_Label => Info.Label,
                Expected => 4,
                Actual => Byte_Count (Size_Byte),
                others => <>)));
      end;
   end if;

   Outcome := Check_Fixed_Payload
     (Object, Info, 4, Graphic_Control_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Streams.Read_Exact (Object.Input.all, Fixed);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   end if;
   Outcome := Internal.Bytes.Read_Byte
     (Object.Input.all, Terminator, Graphic_Control_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   elsif Terminator /= 0 then
      declare
         Prior : constant Streams.Source_Position_Result :=
           Streams.Position (Object.Input.all, 1);
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Has_Source => Prior.Available,
                Source => Prior.Value,
                Block => Graphic_Control_Extension_Block,
                Extension_Label => Info.Label,
                Expected => 0,
                Actual => Byte_Count (Terminator),
                others => <>)));
      end;
   elsif Object.Has_Pending_Control
     and then Object.Options.Strictness = Strict
   then
      return Results.Failure
        (Errors.Make
           (Errors.Duplicate_Graphic_Control,
            (Has_Source => True,
             Source => Info.Offset,
             Block => Graphic_Control_Extension_Block,
             others => <>)));
   end if;

   if Internal.Extension_Arithmetic.Has_Reserved_GCE_Bits (Fixed (1)) then
      if Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Has_Source => True,
                Source => Info.Offset,
                Block => Graphic_Control_Extension_Block,
                Extension_Label => Info.Label,
                Actual => Byte_Count (Fixed (1)),
                others => <>)));
      end if;
      Add_Warning
        (Object,
         Errors.Reserved_Value_Accepted,
         Errors.Compatibility,
         (Has_Source => True,
          Source => Info.Offset,
          Block => Graphic_Control_Extension_Block,
          Extension_Label => Info.Label,
          Actual => Byte_Count (Fixed (1)),
          others => <>));
   end if;
   if Object.Has_Pending_Control then
      Add_Warning
        (Object,
         Errors.Compatibility_Issue,
         Errors.Compatibility,
         (Has_Source => True,
          Source => Info.Offset,
          Block => Graphic_Control_Extension_Block,
          others => <>));
   end if;

   Control := Internal.Extension_Arithmetic.Decode_Graphic_Control
     (Fixed (1), Fixed (2), Fixed (3), Fixed (4));
   Object.Pending_Control := Control;
   Object.Has_Pending_Control := True;
   Info.Has_Graphic_Control := True;
   Info.Graphic_Control := Control;
   Info.Payload_Length := 4;
   Info.Sub_Block_Count := 1;
   Outcome := Start_Retention (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Retain_Chunk (Object, Fixed);
   end if;
   return Outcome;
end Read_Graphic_Control;
