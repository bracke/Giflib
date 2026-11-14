separate (Giflib.Testing.Test_Blocks)
procedure Byte_IO_Is_Little_Endian (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Source : Giflib.Streams.Memory_Source (Storage'Access);
   Outcome : Giflib.Results.Result;
   One : Giflib.Byte;
   Two : Interfaces.Unsigned_16;
begin
   Giflib.Streams.Open (Destination, Max_Transfer => 1);
   Outcome := Giflib.Internal.Bytes.Write_Byte
     (Destination, 16#AA#, Giflib.Logical_Screen_Descriptor_Block);
   Assert (Giflib.Results.Succeeded (Outcome), "byte write failed");
   Outcome := Giflib.Internal.Bytes.Write_U16_LE
     (Destination, 16#1234#, Giflib.Logical_Screen_Descriptor_Block);
   Assert (Giflib.Results.Succeeded (Outcome), "u16 write failed");
   Assert (Storage = [16#AA#, 16#34#, 16#12#], "little-endian output is wrong");

   Giflib.Streams.Open (Source, Max_Transfer => 1);
   Outcome := Giflib.Internal.Bytes.Read_Byte (Source, One, Giflib.Logical_Screen_Descriptor_Block);
   Assert (Giflib.Results.Succeeded (Outcome) and then One = 16#AA#, "byte read failed");
   Outcome := Giflib.Internal.Bytes.Read_U16_LE (Source, Two, Giflib.Logical_Screen_Descriptor_Block);
   Assert (Giflib.Results.Succeeded (Outcome) and then Two = 16#1234#, "u16 read failed");
end Byte_IO_Is_Little_Endian;
