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
   is separate;

   procedure Encoder_Components_Honor_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Produces_Known_LSB_Stream (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Fragments_And_Round_Trips_Large_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_LZW_Encoding;
