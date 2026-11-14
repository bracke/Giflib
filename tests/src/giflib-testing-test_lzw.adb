with Interfaces;
with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Interlacing;
with Giflib.Internal.LZW;
with Giflib.Internal.LZW.Testing;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Bit_Arithmetic;
with Giflib.Internal.LZW_Decoder_Output;
with Giflib.Internal.LZW_Decoder_Reader;
with Giflib.Internal.LZW_Decoder_Dictionary;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_LZW is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Streams.Byte_Array;
   use type Interfaces.Unsigned_32;

   type Natural_Array is array (Positive range <>) of Natural;

   type Counting_Source
     (Storage : not null access constant Giflib.Streams.Byte_Array)
      is limited new Giflib.Streams.Source with record
      Inner : Giflib.Streams.Memory_Source (Storage);
      Read_Calls : Natural := 0;
   end record;

   overriding function Read
     (Object : in out Counting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Counting_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Counting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   procedure Open (Object : in out Counting_Source) is
   begin
      Giflib.Streams.Open (Object.Inner);
      Object.Read_Calls := 0;
   end Open;

   overriding function Read
     (Object : in out Counting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result
   is
   begin
      Object.Read_Calls := Object.Read_Calls + 1;
      return Object.Inner.Read (Buffer);
   end Read;

   overriding function Offset
     (Object : Counting_Source) return Giflib.Source_Offset is
   begin
      return Object.Inner.Offset;
   end Offset;

   overriding function Skip
     (Object : in out Counting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
   begin
      return Object.Inner.Skip (Count);
   end Skip;

   function Pack (Codes, Widths : Natural_Array) return Giflib.Streams.Byte_Array is
      Raw : Giflib.Streams.Byte_Array (1 .. 255) := [others => 0];
      Raw_Length : Natural := 0;
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
   begin
      for I in Codes'Range loop
         Bits := Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Codes (I)), Bit_Count);
         Bit_Count := Bit_Count + Widths (I);
         while Bit_Count >= 8 loop
            Raw_Length := Raw_Length + 1;
            Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
            Bits := Interfaces.Shift_Right (Bits, 8);
            Bit_Count := Bit_Count - 8;
         end loop;
      end loop;
      if Bit_Count > 0 then
         Raw_Length := Raw_Length + 1;
         Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
      end if;
      declare
         Result : Giflib.Streams.Byte_Array (1 .. Raw_Length + 2);
      begin
         Result (1) := Giflib.Byte (Raw_Length);
         Result (2 .. Raw_Length + 1) := Raw (1 .. Raw_Length);
         Result (Result'Last) := 0;
         return Result;
      end;
   end Pack;

   function Literal_Stream (Count : Positive) return Giflib.Streams.Byte_Array is
      Raw : Giflib.Streams.Byte_Array (1 .. 7_000) := [others => 0];
      Raw_Length : Natural := 0;
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Width : Natural := 3;
      Next_Code : Natural := 6;
      Have_Old : Boolean := False;

      procedure Put (Code : Natural) is
      begin
         Bits := Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Code), Bit_Count);
         Bit_Count := Bit_Count + Width;
         while Bit_Count >= 8 loop
            Raw_Length := Raw_Length + 1;
            Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
            Bits := Interfaces.Shift_Right (Bits, 8);
            Bit_Count := Bit_Count - 8;
         end loop;
      end Put;
   begin
      Put (4);
      for I in 0 .. Count - 1 loop
         Put (I mod 4);
         if Have_Old and then Next_Code < 4_096 then
            Next_Code := Next_Code + 1;
            if Next_Code = 2 ** Width and then Width < 12 then
               Width := Width + 1;
            end if;
         end if;
         Have_Old := True;
      end loop;
      Put (5);
      if Bit_Count > 0 then
         Raw_Length := Raw_Length + 1;
         Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
      end if;
      declare
         Block_Count : constant Natural := (Raw_Length + 254) / 255;
         Result : Giflib.Streams.Byte_Array (1 .. Raw_Length + Block_Count + 1);
         Raw_Position : Natural := 1;
         Result_Position : Natural := 1;
      begin
         while Raw_Position <= Raw_Length loop
            declare
               Chunk : constant Natural := Natural'Min (255, Raw_Length - Raw_Position + 1);
            begin
               Result (Result_Position) := Giflib.Byte (Chunk);
               Result_Position := Result_Position + 1;
               Result (Result_Position .. Result_Position + Chunk - 1) :=
                 Raw (Raw_Position .. Raw_Position + Chunk - 1);
               Result_Position := Result_Position + Chunk;
               Raw_Position := Raw_Position + Chunk;
            end;
         end loop;
         Result (Result_Position) := 0;
         return Result;
      end;
   end Literal_Stream;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("lzw");
   end Name;

   procedure Basic_And_Repeated_Clear (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure KwKwK_And_Width_Transition (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Dictionary_Full_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Malformed_Codes_And_Sizes_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Work_And_Code_Size_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decodes_All_Minimum_Code_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Transitions_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Compressed_Input_Is_Buffered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Components_Honor_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Basic_And_Repeated_Clear'Access, "lzw.basic_and_repeated_clear");
      Register_Routine (T, KwKwK_And_Width_Transition'Access, "lzw.kwkwk_and_width_transition");
      Register_Routine (T, Dictionary_Full_Is_Bounded'Access, "lzw.dictionary_full");
      Register_Routine (T, Malformed_Codes_And_Sizes_Fail'Access, "lzw.malformed_and_output_count");
      Register_Routine (T, Work_And_Code_Size_Are_Bounded'Access, "lzw.work_and_code_size_limits");
      Register_Routine (T, Decodes_All_Minimum_Code_Sizes'Access, "lzw.minimum_code_sizes_2_to_8");
      Register_Routine (T, Arithmetic_Transitions_Are_Bounded'Access, "lzw.arithmetic_transitions");
      Register_Routine (T, Bit_Arithmetic_Is_Exact'Access, "lzw.bit_arithmetic");
      Register_Routine (T, Compressed_Input_Is_Buffered'Access, "lzw.buffered_input");
      Register_Routine
        (T, Decoder_Components_Honor_Boundaries'Access,
         "lzw.decoder_component_boundaries");
   end Register_Tests;

   procedure Decoder_Components_Honor_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Compressed_Input_Is_Buffered
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Bit_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Basic_And_Repeated_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure KwKwK_And_Width_Transition (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Dictionary_Full_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Malformed_Codes_And_Sizes_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Work_And_Code_Size_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Decodes_All_Minimum_Code_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Arithmetic_Transitions_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_LZW;
