with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Interlacing;
with Giflib.Internal.LZW;
with Giflib.Internal.LZW.Testing;
with Giflib.Internal.LZW_Encoding;
with Giflib.Internal.LZW_Encoding.Testing;
with Giflib.Internal.LZW_Encoder_Dictionary;
with Giflib.Internal.LZW_Encoder_Input;
with Giflib.Internal.LZW_Encoder_Writer;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_LZW_Encoding is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.LZW_Encoder_Writer.Writer_State;
   use type Giflib.Streams.Byte_Array;

   procedure Produces_Known_LSB_Stream (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Fragments_And_Round_Trips_Large_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encoder_Components_Honor_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encoder_Dictionary_Enforces_Occupancy
     (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine
        (T, Encoder_Components_Honor_Boundaries'Access,
         "lzw_encoding.component_boundaries");
      Register_Routine
        (T, Encoder_Dictionary_Enforces_Occupancy'Access,
         "lzw_encoding.dictionary_occupancy");
   end Register_Tests;

   procedure Encoder_Dictionary_Enforces_Occupancy
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Dictionary renames Giflib.Internal.LZW_Encoder_Dictionary;
      Storage : aliased Giflib.Streams.Byte_Array := [0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Object : Dictionary.Dictionary;
      Work : Giflib.Internal.Work_Budgets.Meter
        (Giflib.Byte_Count (Dictionary.Hash_Size * 2 + 10));
      Found : Boolean;
      Slot : Dictionary.Slot_Index;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination);
      Assert
        (not Dictionary.Is_Initialized (Object),
         "encoder dictionary unexpectedly started initialized");
      Outcome := Dictionary.Clear (Object, Work, Destination);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Dictionary.Is_Initialized (Object)
         and then Dictionary.Occupied_Count (Object) = 0,
         "encoder dictionary did not start an empty generation");
      Outcome := Dictionary.Find
        (Object, 0, 0, Work, Destination, Found, Slot);
      Assert
        (Giflib.Results.Succeeded (Outcome) and then not Found
         and then not Dictionary.Is_Occupied (Object, Slot),
         "encoder dictionary returned an occupied insertion slot");
      Dictionary.Insert (Object, Slot, 0, 0, 6);
      Outcome := Dictionary.Find
        (Object, 0, 0, Work, Destination, Found, Slot);
      Assert
        (Giflib.Results.Succeeded (Outcome) and then Found
         and then Dictionary.Matches (Object, Slot, 0, 0)
         and then Dictionary.Code_At (Object, Slot) = 6,
         "encoder dictionary lost an inserted code");

      Outcome := Dictionary.Clear (Object, Work, Destination);
      Assert (Giflib.Results.Succeeded (Outcome),
              "encoder dictionary generation reset failed");
      for Index in Dictionary.Slot_Index loop
         Dictionary.Insert (Object, Index, 0, 0, 6);
      end loop;
      Outcome := Dictionary.Find
        (Object, 1, 1, Work, Destination, Found, Slot);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
         "full encoder dictionary did not stop after one probe cycle");
   end Encoder_Dictionary_Enforces_Occupancy;

   procedure Encoder_Components_Honor_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [0, 1, 2, 3, 4, 5, 6, 7];
      Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Blocks_Writer : Giflib.Internal.Blocks.Sub_Block_Writer;
      Writer : Giflib.Internal.LZW_Encoder_Writer.Code_Writer;
      Work : Giflib.Internal.Work_Budgets.Meter (100);
      Outcome : Giflib.Results.Result;
   begin
      Assert
        (Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
           Giflib.Internal.LZW_Encoder_Writer.Open,
         "encoder writer did not start open");
      Assert
        (Giflib.Internal.LZW_Encoder_Input.Element
           (Input, 2, Giflib.Internal.Interlacing.Sequential_Layout) = 2,
         "encoder input changed a sequential element");
      Assert
        (Giflib.Internal.LZW_Encoder_Input.Element
           (Input, 2,
            (Is_Interlaced => True, Width => 2, Height => 4)) = 4,
         "encoder input did not apply GIF interlace order");

      Giflib.Streams.Open (Destination);
      Giflib.Internal.Blocks.Initialize (Blocks_Writer, 2, 4);
      Outcome := Giflib.Internal.LZW_Encoder_Writer.Put
        (Writer, Blocks_Writer, Destination, Work, 4, 3);
      Assert (Giflib.Results.Succeeded (Outcome),
              "encoder writer rejected a valid code");
      Outcome := Giflib.Internal.LZW_Encoder_Writer.Finish
        (Writer, Blocks_Writer, Destination);
      Assert (Giflib.Results.Succeeded (Outcome),
              "encoder writer did not flush its partial byte");
      Assert
        (Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
           Giflib.Internal.LZW_Encoder_Writer.Finished,
         "encoder writer did not expose its finished state");
      Outcome := Giflib.Internal.Blocks.Finish (Blocks_Writer, Destination);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Destination.Offset = 3
         and then Storage (1 .. 3) = [1, 4, 0],
         "encoder writer produced the wrong sub-block framing");
      Outcome := Giflib.Internal.LZW_Encoder_Writer.Put
        (Writer, Blocks_Writer, Destination, Work, 4, 3);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
         and then Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
           Giflib.Internal.LZW_Encoder_Writer.Finished,
         "encoder writer accepted a code after finishing");
   end Encoder_Components_Honor_Boundaries;

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

   procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : constant Giflib.Streams.Byte_Array := [0, 1, 2, 3];
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 32 => 0];
      Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Context : Giflib.Internal.LZW_Encoding.Testing.Workspace;
      Outcome : Giflib.Results.Result;
      Compressed : Giflib.Byte_Count;
   begin
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
        (Context, Destination, Input, 2, 1, 100, 100, Compressed);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "LZW encoding work budget was ignored");

      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
        (Context, Destination, Input, 2, 1_000, 1, 100, Compressed);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "compressed output budget was ignored");
   end Enforces_Encoding_Budgets;
end Giflib.Testing.Test_LZW_Encoding;
