with Interfaces;
with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.LZW_Bit_Arithmetic;
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
   end Register_Tests;

   procedure Compressed_Input_Is_Buffered
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Item_Count : constant Positive := 1_024;
      Input : aliased constant Giflib.Streams.Byte_Array :=
        Literal_Stream (Item_Count);
      Source : Counting_Source (Input'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. Item_Count);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Open (Source);
      Giflib.Internal.Blocks.Initialize
        (Reader,
         Giflib.Byte_Count (Input'Length),
         Giflib.Compressed_Byte_Limit,
         Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output, Count, 100_000);
      Assert (Giflib.Results.Succeeded (Outcome),
              "buffered LZW fixture failed");
      Assert (Count = Giflib.Byte_Count (Item_Count)
              and then Source.Read_Calls < Input'Length / 8,
              "LZW decoder reverted to per-byte source reads");
   end Compressed_Input_Is_Buffered;

   procedure Bit_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.LZW_Bit_Arithmetic;
      Packed : Arithmetic.Bit_State := Arithmetic.Append_Code (0, 0, 4, 3);
      First : Giflib.Byte;
      Decoded : Arithmetic.Extracted_Code;
   begin
      Packed := Arithmetic.Append_Code
        (Packed.Bits, Arithmetic.Encoder_Append_Count (Packed.Count), 3, 3);
      Packed := Arithmetic.Append_Code
        (Packed.Bits, Arithmetic.Encoder_Append_Count (Packed.Count), 5, 3);
      First := Arithmetic.First_Byte (Packed.Bits);
      Assert (First = 16#5C#, "LSB-first code packing is wrong");

      declare
         Dropped : constant Arithmetic.Bit_State :=
           Arithmetic.Drop_Byte (Packed.Bits, Packed.Count);
         Appended : constant Arithmetic.Bit_State :=
           Arithmetic.Append_Byte
             (0, 0, First);
      begin
         Assert (Dropped.Count = 1 and then Dropped.Bits = 1,
                 "encoded bit-buffer drain is wrong");
         Decoded := Arithmetic.Extract (Appended.Bits, Appended.Count, 3);
         Assert (Decoded.Code = 4, "first packed code decoded incorrectly");
         Decoded := Arithmetic.Extract
           (Decoded.State.Bits, Decoded.State.Count, 3);
         Assert (Decoded.Code = 3, "second packed code decoded incorrectly");
      end;
   end Bit_Arithmetic_Is_Exact;

   procedure Basic_And_Repeated_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Basic : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
      Repeated : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 4, 1, 5], [3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source (Basic'Access);
      Repeated_Source : Giflib.Streams.Memory_Source (Repeated'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output, Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome), "basic LZW stream failed");
      Assert (Count = 2 and then Output = [0, 1], "basic LZW output is wrong");

      Giflib.Streams.Open (Repeated_Source);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Repeated_Source, Reader, 2, Output (1 .. 1), Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome), "repeated clear codes failed");
      Assert (Count = 1 and then Output (1) = 1, "repeated-clear output is wrong");
   end Basic_And_Repeated_Clear;

   procedure KwKwK_And_Width_Transition (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      KwKwK : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 6, 5], [3, 3, 3, 3]);
      Wider : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 2, 3, 5], [3, 3, 3, 3, 4, 4]);
      Source : Giflib.Streams.Memory_Source (KwKwK'Access);
      Wider_Source : Giflib.Streams.Memory_Source (Wider'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. 4);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output (1 .. 3), Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome) and then Output (1 .. 3) = [0, 0, 0],
              "KwKwK sequence failed");

      Giflib.Streams.Open (Wider_Source);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Wider_Source, Reader, 2, Output, Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome) and then Output = [0, 1, 2, 3],
              "code-width transition failed");
   end KwKwK_And_Width_Transition;

   procedure Dictionary_Full_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Item_Count : constant Positive := 4_093;
      Input : aliased constant Giflib.Streams.Byte_Array := Literal_Stream (Item_Count);
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. Item_Count);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 3);
      Giflib.Internal.Blocks.Initialize
        (Reader, Giflib.Byte_Count (Input'Length), Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output, Count, 100_000);
      Assert (Giflib.Results.Succeeded (Outcome), "full 12-bit dictionary stream failed");
      Assert (Count = Giflib.Byte_Count (Item_Count), "dictionary-full output count is wrong");
      for I in Output'Range loop
         Assert (Output (I) = Giflib.Byte ((I - 1) mod 4), "dictionary-full literal changed");
      end loop;
   end Dictionary_Full_Is_Bounded;

   procedure Malformed_Codes_And_Sizes_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Forward : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 7, 5], [3, 3, 3, 3]);
      Early_End : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 5], [3, 3, 3]);
      Excess : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
      No_Initial_Clear : aliased constant Giflib.Streams.Byte_Array := Pack ([0, 5], [3, 3]);
      No_End : aliased constant Giflib.Streams.Byte_Array :=
        Pack ([4, 0, 0, 0, 0, 0, 0, 0], [3, 3, 3, 3, 3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source (Forward'Access);
      Early_Source : Giflib.Streams.Memory_Source (Early_End'Access);
      Excess_Source : Giflib.Streams.Memory_Source (Excess'Access);
      No_Clear_Source : Giflib.Streams.Memory_Source (No_Initial_Clear'Access);
      No_End_Source : Giflib.Streams.Memory_Source (No_End'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. 7);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;

      procedure Start (Input : in out Giflib.Streams.Memory_Source) is
      begin
         Giflib.Streams.Open (Input);
         Giflib.Internal.Blocks.Initialize
           (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      end Start;
   begin
      Start (Source);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output (1 .. 3), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
              "forward dictionary reference was accepted");

      Start (Early_Source);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Early_Source, Reader, 2, Output (1 .. 2), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
              "early end code was accepted");

      Start (Excess_Source);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Excess_Source, Reader, 2, Output (1 .. 1), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
              "excess output was accepted");

      Start (No_Clear_Source);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, No_Clear_Source, Reader, 2, Output (1 .. 1), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
              "stream without an initial clear code was accepted");
      Assert
        (Outcome.First_Error.Context.LZW.Present
         and then Outcome.First_Error.Context.Expected = 4
         and then Outcome.First_Error.Context.Actual = 0,
         "missing-initial-clear diagnostic context is wrong");

      Start (No_End_Source);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, No_End_Source, Reader, 2, Output, Count, 1_000);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Missing_End_Code,
              "missing end code was accepted");
   end Malformed_Codes_And_Sizes_Fail;

   procedure Work_And_Code_Size_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source (Input'Access);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 1, Output, Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Minimum_Code_Size,
              "invalid minimum code size was accepted");

      Giflib.Streams.Open (Source);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode
        (Context, Source, Reader, 2, Output, Count, 1);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "LZW work limit was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.LZW_Work_Limit,
              "LZW work failure lost limit context");
   end Work_And_Code_Size_Are_Bounded;

   procedure Decodes_All_Minimum_Code_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Context : Giflib.Internal.LZW.Workspace;
      Output : Giflib.Streams.Byte_Array (1 .. 1);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      for Minimum in 2 .. 8 loop
         declare
            Clear : constant Natural := 2 ** Minimum;
            Input : aliased constant Giflib.Streams.Byte_Array :=
              Pack ([Clear, Clear - 1, Clear + 1],
                    [Minimum + 1, Minimum + 1, Minimum + 1]);
            Source : Giflib.Streams.Memory_Source (Input'Access);
         begin
            Giflib.Streams.Open (Source);
            Giflib.Internal.Blocks.Initialize
              (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
            Outcome := Giflib.Internal.LZW.Decode
              (Context, Source, Reader, Giflib.Byte (Minimum), Output, Count, 100);
            Assert (Giflib.Results.Succeeded (Outcome)
                    and then Output (1) = Giflib.Byte (Clear - 1),
                    "valid minimum code size" & Natural'Image (Minimum) & " failed");
         end;
      end loop;
   end Decodes_All_Minimum_Code_Sizes;

   procedure Arithmetic_Transitions_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.LZW_Arithmetic;
   begin
      for Minimum in Arithmetic.Minimum_Code_Size loop
         declare
            State : constant Arithmetic.Initial_Code_State := Arithmetic.Initialize (Minimum);
         begin
            Assert (State.Clear_Code = 2 ** Minimum, "wrong LZW clear code");
            Assert (State.End_Code = State.Clear_Code + 1, "wrong LZW end code");
            Assert (State.First_Free_Code = State.Clear_Code + 2, "wrong first dictionary code");
            Assert (State.Width = Minimum + 1, "wrong initial LZW width");
         end;
      end loop;

      for Width in Arithmetic.Active_Code_Width range 3 .. 11 loop
         Assert
           (Arithmetic.Decoder_Width_After_Insert
              (Arithmetic.Next_Code_Value (2 ** Width), Width) = Width + 1,
            "decoder width did not advance at its boundary");
         Assert
           (Arithmetic.Encoder_Width_After_Insert
              (Arithmetic.Next_Code_Value (2 ** Width + 1), Width) = Width + 1,
            "encoder width did not advance at its boundary");
      end loop;

      Assert
        (Arithmetic.Next_Hash_Slot (Arithmetic.Hash_Slot'Last) = Arithmetic.Hash_Slot'First,
         "LZW hash probing did not wrap");
      Assert
        (Arithmetic.Hash_Start (4_095, 255) = 4_094,
         "wrong LZW hash start at the maximum code and suffix");
      Assert
        (Arithmetic.Can_Follow (4_095, 6, 4_096, 4_095)
         and then not Arithmetic.Can_Follow (4_095, 6, 4_095, 4_095)
         and then Arithmetic.Push_Count (4_095) = 4_096,
         "dictionary traversal bounds are wrong");
      Assert
        (Arithmetic.Can_Insert (4_095)
         and then Arithmetic.After_Insert (4_095) = 4_096
         and then not Arithmetic.Can_Insert (4_096),
         "dictionary insertion bounds are wrong");
   end Arithmetic_Transitions_Are_Bounded;
end Giflib.Testing.Test_LZW;
