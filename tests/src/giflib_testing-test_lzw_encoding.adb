with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW;
with Giflib.Internal.LZW_Encoding;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_LZW_Encoding is
   use AUnit.Assertions;
   use type Giflib.Byte;
   use type Giflib.Byte_Count;
   use type Giflib.Destination_Offset;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Streams.Byte_Array;

   procedure Produces_Known_LSB_Stream (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Fragments_And_Round_Trips_Large_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("lzw_encoding");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Produces_Known_LSB_Stream'Access, "lzw_encoding.known_stream");
      Register_Routine (T, Fragments_And_Round_Trips_Large_Input'Access,
                        "lzw_encoding.fragmentation_and_dictionary_reset");
      Register_Routine (T, Enforces_Encoding_Budgets'Access, "lzw_encoding.budgets");
   end Register_Tests;

   procedure Produces_Known_LSB_Stream (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [0, 1];
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Outcome : Giflib.Results.Result;
      Compressed : Giflib.Byte_Count;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Internal.LZW_Encoding.Encode
        (Destination, Input, 2, 1_000, 100, 100, Compressed);
      Assert (Giflib.Results.Succeeded (Outcome), "known LZW encode failed");
      Assert (Destination.Offset = 4, "known LZW stream length is wrong");
      Assert (Storage (1 .. 4) = [2, 16#44#, 16#0A#, 0],
              "known LSB-first code stream changed");
   end Produces_Known_LSB_Stream;

   function Pseudorandom_Input return Giflib.Streams.Byte_Array is
      Result : Giflib.Streams.Byte_Array (1 .. 20_000);
      Value : Natural := 17;
   begin
      for I in Result'Range loop
         Value := (Value * 251 + 97) mod 65_521;
         Result (I) := Giflib.Byte (Value mod 256);
      end loop;
      return Result;
   end Pseudorandom_Input;

   procedure Fragments_And_Round_Trips_Large_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := Pseudorandom_Input;
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 40_000 => 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Decoded : Giflib.Streams.Byte_Array (Input'Range);
      Decoded_Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
      Compressed : Giflib.Byte_Count;
      Position : Natural := 1;
      Saw_Full_Block : Boolean := False;
      Length : Natural;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 7);
      Outcome := Giflib.Internal.LZW_Encoding.Encode
        (Destination, Input, 8, 10_000_000, 40_000, 40_000, Compressed);
      Assert (Giflib.Results.Succeeded (Outcome), "large LZW encode failed");
      while Storage (Position) /= 0 loop
         Length := Natural (Storage (Position));
         Assert (Length <= 255, "illegal sub-block length");
         Saw_Full_Block := Saw_Full_Block or else Length = 255;
         Position := Position + Length + 1;
      end loop;
      Assert (Saw_Full_Block, "large output was not fragmented at 255 bytes");

      Giflib.Streams.Open (Source, Storage'Unchecked_Access, Max_Transfer => 5);
      Giflib.Internal.Blocks.Initialize
        (Reader, 40_000, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Source, Reader, 8, Decoded, Decoded_Count, 10_000_000);
      Assert (Giflib.Results.Succeeded (Outcome), "large encoded stream did not decode");
      Assert (Decoded_Count = Giflib.Byte_Count (Input'Length) and then Decoded = Input,
              "large LZW round trip changed indices");
   end Fragments_And_Round_Trips_Large_Input;

   procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [0, 1, 2, 3];
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 32 => 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination;
      Outcome : Giflib.Results.Result;
      Compressed : Giflib.Byte_Count;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Internal.LZW_Encoding.Encode
        (Destination, Input, 2, 1, 100, 100, Compressed);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "LZW encoding work budget was ignored");

      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Internal.LZW_Encoding.Encode
        (Destination, Input, 2, 1_000, 1, 100, Compressed);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "compressed output budget was ignored");
   end Enforces_Encoding_Budgets;
end Giflib_Testing.Test_LZW_Encoding;
