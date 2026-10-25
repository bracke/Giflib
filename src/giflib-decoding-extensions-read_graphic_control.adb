separate (Giflib.Decoding.Extensions)
function Read_Graphic_Control
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   Terminator : Byte;
   Fixed : Streams.Byte_Array (1 .. 4);
   Control : Frames.Graphic_Control;
   Outcome : Results.Result;
begin
   Outcome := Read_Fixed_Block (Object, Info, Fixed);
   if not Results.Succeeded (Outcome) then
      return Outcome;
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
               (Source_Position =>
                  Internal.Diagnostics.With_Source ((others => <>), Prior).Source_Position,
                Block => Graphic_Control_Extension_Block,
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Info)),
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
            (Source_Position => Errors.Source_Position_At (Info.Offset),
             Block => Graphic_Control_Extension_Block,
             others => <>)));
   end if;

   if Internal.Extension_Arithmetic.Has_Reserved_GCE_Bits (Fixed (1)) then
      if Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Source_Position => Errors.Source_Position_At (Info.Offset),
                Block => Graphic_Control_Extension_Block,
                Extension_Label =>
                  Errors.Extension_Label_At (Metadata.Label_Of (Info)),
                Actual => Byte_Count (Fixed (1)),
                others => <>)));
      end if;
      Add_Warning
        (Object,
         Errors.Reserved_Value_Accepted,
         Errors.Compatibility,
         (Source_Position => Errors.Source_Position_At (Info.Offset),
          Block => Graphic_Control_Extension_Block,
          Extension_Label =>
            Errors.Extension_Label_At (Metadata.Label_Of (Info)),
          Actual => Byte_Count (Fixed (1)),
          others => <>));
   end if;
   if Object.Has_Pending_Control then
      Add_Warning
        (Object,
         Errors.Compatibility_Issue,
         Errors.Compatibility,
         (Source_Position => Errors.Source_Position_At (Info.Offset),
          Block => Graphic_Control_Extension_Block,
          others => <>));
   end if;

   Control := Internal.Extension_Arithmetic.Decode_Graphic_Control
     (Fixed (1), Fixed (2), Fixed (3), Fixed (4));
   Object.Pending_Control := Control;
   Object.Has_Pending_Control := True;
   Info.Graphic_Control := Control;
   Info.Payload_Length := 4;
   Info.Sub_Block_Count := 1;
   Outcome := Start_Retention (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Retain_Chunk (Object, Fixed);
   end if;
   return Outcome;
end Read_Graphic_Control;
