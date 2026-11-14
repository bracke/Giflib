separate (Giflib.Testing.Test_LZW_Encoding)
procedure Fragments_And_Round_Trips_Large_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := Pseudorandom_Input;
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 40_000 => 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Source : Giflib.Streams.Memory_Source (Storage'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Encode_Context : Giflib.Internal.LZW_Encoding.Testing.Workspace;
   Decode_Context : Giflib.Internal.LZW.Testing.Workspace;
   Decoded : Giflib.Streams.Byte_Array (Input'Range);
   Decoded_Count : Giflib.Byte_Count;
   Outcome : Giflib.Results.Result;
   Compressed : Giflib.Byte_Count;
   Position : Natural := 1;
   Saw_Full_Block : Boolean := False;
   Length : Natural;
begin
   Giflib.Streams.Open (Destination, Max_Transfer => 7);
   Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
     (Encode_Context, Destination, Input, 8, 10_000_000, 40_000, 40_000,
      Compressed);
   Assert (Giflib.Results.Succeeded (Outcome), "large LZW encode failed");
   while Storage (Position) /= 0 loop
      Length := Natural (Storage (Position));
      Assert (Length <= 255, "illegal sub-block length");
      Saw_Full_Block := Saw_Full_Block or else Length = 255;
      Position := Position + Length + 1;
   end loop;
   Assert (Saw_Full_Block, "large output was not fragmented at 255 bytes");

   Giflib.Streams.Open (Source, Max_Transfer => 5);
   Giflib.Internal.Blocks.Initialize
     (Reader, 40_000, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.LZW.Testing.Decode
     (Decode_Context, Source, Reader, 8, Decoded, Decoded_Count, 10_000_000);
   Assert (Giflib.Results.Succeeded (Outcome), "large encoded stream did not decode");
   Assert (Decoded_Count = Giflib.Byte_Count (Input'Length) and then Decoded = Input,
           "large LZW round trip changed indices");
end Fragments_And_Round_Trips_Large_Input;
