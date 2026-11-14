separate (Giflib.Decoding.Extensions)
function Read_Application
  (Object : in out Decoder;
   Info : in out Metadata.Extension_Info) return Results.Result
is
   Fixed : Streams.Byte_Array (1 .. 11);
   First_Data : Streams.Byte_Array (1 .. 255);
   First_Length : Natural;
   Outcome : Results.Result;
begin
   Outcome := Transport.Read_Fixed_Block (Object, Info, Fixed);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;
   for I in Info.Identifier'Range loop
      Info.Identifier (I) := Fixed (I);
   end loop;
   for I in Info.Authentication_Code'Range loop
      Info.Authentication_Code (I) := Fixed (8 + I);
   end loop;
   Info.Payload_Length := 11;
   Info.Sub_Block_Count := 1;
   Outcome := Retention.Start (Object, Info);
   if Results.Succeeded (Outcome) then
      Outcome := Retention.Append (Object, Fixed);
   end if;
   if Results.Succeeded (Outcome) then
      Outcome := Transport.Read_Sub_Blocks
        (Object, Info, First_Data, First_Length);
   end if;
   if Results.Succeeded (Outcome)
     and then First_Length = 3
     and then First_Data (1) = 1
     and then Internal.Loop_Extensions.Is_Loop_Application
       (Info.Identifier, Info.Authentication_Code)
   then
      Info.Loop_Info :=
        (Is_Loop => True,
         Count => Internal.Extension_Arithmetic.Decode_U16_LE
           (First_Data (2), First_Data (3)));
      Session_Transitions.Set_Loop
        (Object,
         (if Info.Loop_Info.Count = 0
          then (State => Animations.Infinite_Looping)
          else (State => Animations.Finite_Loop_Count,
                Count => Info.Loop_Info.Count)));
   end if;
   return Outcome;
end Read_Application;
