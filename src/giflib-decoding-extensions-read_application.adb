separate (Giflib.Decoding.Extensions)
function Read_Application
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   use type Metadata.Application_Authentication_Code;
   use type Metadata.Application_Identifier;
   Size_Byte : Byte;
   Fixed : Streams.Byte_Array (1 .. 11);
   First_Data : Streams.Byte_Array (1 .. 255);
   First_Length : Natural;
   Outcome : Results.Result;
   Netscape : constant Metadata.Application_Identifier :=
     [Character'Pos ('N'), Character'Pos ('E'), Character'Pos ('T'),
      Character'Pos ('S'), Character'Pos ('C'), Character'Pos ('A'),
      Character'Pos ('P'), Character'Pos ('E')];
   Animexts : constant Metadata.Application_Identifier :=
     [Character'Pos ('A'), Character'Pos ('N'), Character'Pos ('I'),
      Character'Pos ('M'), Character'Pos ('E'), Character'Pos ('X'),
      Character'Pos ('T'), Character'Pos ('S')];
   Netscape_Auth : constant Metadata.Application_Authentication_Code :=
     [Character'Pos ('2'), Character'Pos ('.'), Character'Pos ('0')];
   Animexts_Auth : constant Metadata.Application_Authentication_Code :=
     [Character'Pos ('1'), Character'Pos ('.'), Character'Pos ('0')];
begin
   Outcome := Internal.Bytes.Read_Byte
     (Object.Input.all, Size_Byte, Application_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   elsif Size_Byte /= 11 then
      declare
         Prior : constant Streams.Source_Position_Result :=
           Streams.Position (Object.Input.all, 1);
      begin
         return Results.Failure
           (Errors.Make
              (Errors.Invalid_Extension,
               (Has_Source => Prior.Available,
                Source => Prior.Value,
                Block => Application_Extension_Block,
                Extension_Label => Info.Label,
                Expected => 11,
                Actual => Byte_Count (Size_Byte),
                others => <>)));
      end;
   end if;

   Outcome := Check_Fixed_Payload
     (Object, Info, 11, Application_Extension_Block);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   Outcome := Streams.Read_Exact (Object.Input.all, Fixed);
   if not Results.Succeeded (Outcome) then
      return Truncated (Object, Info, Outcome);
   end if;
   Info.Has_Application_Identifier := True;
   for I in Info.Identifier'Range loop
      Info.Identifier (I) := Fixed (I);
   end loop;
   for I in Info.Authentication_Code'Range loop
      Info.Authentication_Code (I) := Fixed (8 + I);
   end loop;
   Info.Payload_Length := 11;
   Info.Sub_Block_Count := 1;
   Outcome := Start_Retention (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Retain_Chunk (Object, Fixed);
   end if;
   if Results.Succeeded (Outcome) then
      Outcome := Read_Sub_Blocks
        (Object, Info, First_Data, First_Length);
   end if;
   if Results.Succeeded (Outcome)
     and then First_Length = 3
     and then First_Data (1) = 1
     and then
       ((Info.Identifier = Netscape
         and then Info.Authentication_Code = Netscape_Auth)
        or else
          (Info.Identifier = Animexts
           and then Info.Authentication_Code = Animexts_Auth))
   then
      Info.Is_Loop_Extension := True;
      Info.Loop_Count := Internal.Extension_Arithmetic.Decode_U16_LE
        (First_Data (2), First_Data (3));
      Object.Loop_Data :=
        (State =>
           (if Info.Loop_Count = 0
            then Animations.Infinite_Looping
            else Animations.Finite_Loop_Count),
         Raw_Count => Info.Loop_Count);
   end if;
   return Outcome;
end Read_Application;
