with Interfaces;
with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.LZW;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_LZW is
   use AUnit.Assertions;
   use type Giflib.Byte;
   use type Giflib.Byte_Count;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Limit_Kind;
   use type Giflib.Streams.Byte_Array;
   use type Interfaces.Unsigned_32;

   type Natural_Array is array (Positive range <>) of Natural;

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

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Basic_And_Repeated_Clear'Access, "lzw.basic_and_repeated_clear");
      Register_Routine (T, KwKwK_And_Width_Transition'Access, "lzw.kwkwk_and_width_transition");
      Register_Routine (T, Dictionary_Full_Is_Bounded'Access, "lzw.dictionary_full");
      Register_Routine (T, Malformed_Codes_And_Sizes_Fail'Access, "lzw.malformed_and_output_count");
      Register_Routine (T, Work_And_Code_Size_Are_Bounded'Access, "lzw.work_and_code_size_limits");
      Register_Routine (T, Decodes_All_Minimum_Code_Sizes'Access, "lzw.minimum_code_sizes_2_to_8");
   end Register_Tests;

   procedure Basic_And_Repeated_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Basic : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
      Repeated : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 4, 1, 5], [3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Basic'Unchecked_Access, Max_Transfer => 1);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output, Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome), "basic LZW stream failed");
      Assert (Count = 2 and then Output = [0, 1], "basic LZW output is wrong");

      Giflib.Streams.Open (Source, Repeated'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output (1 .. 1), Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome), "repeated clear codes failed");
      Assert (Count = 1 and then Output (1) = 1, "repeated-clear output is wrong");
   end Basic_And_Repeated_Clear;

   procedure KwKwK_And_Width_Transition (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      KwKwK : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 6, 5], [3, 3, 3, 3]);
      Wider : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 2, 3, 5], [3, 3, 3, 3, 4, 4]);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Output : Giflib.Streams.Byte_Array (1 .. 4);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, KwKwK'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output (1 .. 3), Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome) and then Output (1 .. 3) = [0, 0, 0],
              "KwKwK sequence failed");

      Giflib.Streams.Open (Source, Wider'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output, Count, 100);
      Assert (Giflib.Results.Succeeded (Outcome) and then Output = [0, 1, 2, 3],
              "code-width transition failed");
   end KwKwK_And_Width_Transition;

   procedure Dictionary_Full_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Item_Count : constant Positive := 4_093;
      Input : aliased constant Giflib.Streams.Byte_Array := Literal_Stream (Item_Count);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Output : Giflib.Streams.Byte_Array (1 .. Item_Count);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 3);
      Giflib.Internal.Blocks.Initialize
        (Reader, Giflib.Byte_Count (Input'Length), Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output, Count, 100_000);
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
      No_End : aliased constant Giflib.Streams.Byte_Array :=
        Pack ([4, 0, 0, 0, 0, 0, 0, 0], [3, 3, 3, 3, 3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Output : Giflib.Streams.Byte_Array (1 .. 7);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;

      procedure Start (Input : not null Giflib.Streams.Const_Byte_Array_Access) is
      begin
         Giflib.Streams.Open (Source, Input);
         Giflib.Internal.Blocks.Initialize
           (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      end Start;
   begin
      Start (Forward'Unchecked_Access);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output (1 .. 3), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
              "forward dictionary reference was accepted");

      Start (Early_End'Unchecked_Access);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output (1 .. 2), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
              "early end code was accepted");

      Start (Excess'Unchecked_Access);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output (1 .. 1), Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Output_Size_Mismatch,
              "excess output was accepted");

      Start (No_End'Unchecked_Access);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output, Count, 1_000);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Missing_End_Code,
              "missing end code was accepted");
   end Malformed_Codes_And_Sizes_Fail;

   procedure Work_And_Code_Size_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input : aliased constant Giflib.Streams.Byte_Array := Pack ([4, 0, 1, 5], [3, 3, 3, 3]);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
      Output : Giflib.Streams.Byte_Array (1 .. 2);
      Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Input'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 1, Output, Count, 100);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Minimum_Code_Size,
              "invalid minimum code size was accepted");

      Giflib.Streams.Open (Source, Input'Unchecked_Access);
      Giflib.Internal.Blocks.Initialize
        (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
      Outcome := Giflib.Internal.LZW.Decode (Source, Reader, 2, Output, Count, 1);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "LZW work limit was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.LZW_Work_Limit,
              "LZW work failure lost limit context");
   end Work_And_Code_Size_Are_Bounded;

   procedure Decodes_All_Minimum_Code_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : Giflib.Streams.Memory_Source;
      Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
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
         begin
            Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 1);
            Giflib.Internal.Blocks.Initialize
              (Reader, 100, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
            Outcome := Giflib.Internal.LZW.Decode
              (Source, Reader, Giflib.Byte (Minimum), Output, Count, 100);
            Assert (Giflib.Results.Succeeded (Outcome)
                    and then Output (1) = Giflib.Byte (Clear - 1),
                    "valid minimum code size" & Natural'Image (Minimum) & " failed");
         end;
      end loop;
   end Decodes_All_Minimum_Code_Sizes;
end Giflib_Testing.Test_LZW;
