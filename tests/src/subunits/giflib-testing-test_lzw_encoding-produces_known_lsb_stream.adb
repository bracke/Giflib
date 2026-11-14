separate (Giflib.Testing.Test_LZW_Encoding)
procedure Produces_Known_LSB_Stream (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [0, 1];
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Context : Giflib.Internal.LZW_Encoding.Testing.Workspace;
   Outcome : Giflib.Results.Result;
   Compressed : Giflib.Byte_Count;
begin
   Giflib.Streams.Open (Destination, Max_Transfer => 1);
   Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
     (Context, Destination, Input, 2, 1_000, 100, 100, Compressed);
   Assert (Giflib.Results.Succeeded (Outcome), "known LZW encode failed");
   Assert (Destination.Offset = 4, "known LZW stream length is wrong");
   Assert (Storage (1 .. 4) = [2, 16#44#, 16#0A#, 0],
           "known LSB-first code stream changed");
end Produces_Known_LSB_Stream;
