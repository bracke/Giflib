with Interfaces;
with Giflib;

package body Giflib_Fuzz_LZW_Stress is
   use type Interfaces.Unsigned_32;

   function Image_Data (Uniform : Boolean) return Giflib.Streams.Byte_Array is
      Raw : Giflib.Streams.Byte_Array (1 .. 8_192) := [others => 0];
      Raw_Length : Natural := 0;
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Width : Natural := 9;
      Next_Code : Natural := 258;
      Have_Old : Boolean := False;

      procedure Put (Code : Natural) is
      begin
         Bits := Bits or Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Code), Bit_Count);
         Bit_Count := Bit_Count + Width;
         while Bit_Count >= 8 loop
            Raw_Length := Raw_Length + 1;
            Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
            Bits := Interfaces.Shift_Right (Bits, 8);
            Bit_Count := Bit_Count - 8;
         end loop;
      end Put;

      procedure Reset_Dictionary is
      begin
         Put (256);
         Width := 9;
         Next_Code := 258;
         Have_Old := False;
      end Reset_Dictionary;

      procedure Put_Data_Code (Code : Natural) is
      begin
         Put (Code);
         if Have_Old and then Next_Code < 4_096 then
            Next_Code := Next_Code + 1;
            if Next_Code = 2 ** Width and then Width < 12 then
               Width := Width + 1;
            end if;
         end if;
         Have_Old := True;
      end Put_Data_Code;
   begin
      Reset_Dictionary;
      if Uniform then
         --  GIF LZW's KwKwK sequence for 4,095 zero-valued pixels: the
         --  literal contributes one pixel and each next-free code expands to
         --  a string one pixel longer.  The final literal reaches 4,096.
         Put_Data_Code (0);
         for Code in 258 .. 346 loop
            Put_Data_Code (Code);
         end loop;
         Put_Data_Code (0);
      else
         --  Literal codes deliberately grow the decoder dictionary to its
         --  4,096-entry ceiling, after which an explicit Clear restarts it.
         for Position in 0 .. 4_095 loop
            Put_Data_Code ((Position + Position / 256) mod 256);
            if Next_Code = 4_096 and then Position < 4_095 then
               Reset_Dictionary;
            end if;
         end loop;
      end if;
      Put (257);
      if Bit_Count > 0 then
         Raw_Length := Raw_Length + 1;
         Raw (Raw_Length) := Giflib.Byte (Bits and 16#FF#);
      end if;
      declare
         Block_Count : constant Natural := (Raw_Length + 254) / 255;
         Result : Giflib.Streams.Byte_Array
           (1 .. Raw_Length + Block_Count + 1);
         Raw_Position : Natural := 1;
         Result_Position : Natural := 1;
      begin
         while Raw_Position <= Raw_Length loop
            declare
               Chunk : constant Natural :=
                 Natural'Min (255, Raw_Length - Raw_Position + 1);
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
   end Image_Data;

   function Make (Uniform : Boolean) return Giflib.Streams.Byte_Array is
      Data : constant Giflib.Streams.Byte_Array := Image_Data (Uniform);
      Prefix_Length : constant Positive := 792;
      Result : Giflib.Streams.Byte_Array
        (1 .. Prefix_Length + Data'Length + 1) := [others => 0];
      Position : Positive := Result'First;

      procedure Put (Value : Giflib.Byte) is
      begin
         Result (Position) := Value;
         Position := Position + 1;
      end Put;
   begin
      for Value of Giflib.Streams.Byte_Array'
        ([71, 73, 70, 56, 57, 97,
          64, 0, 64, 0, 16#F7#, 0, 0])
      loop
         Put (Value);
      end loop;
      for Index in 0 .. 255 loop
         Put (Giflib.Byte (Index));
         Put (Giflib.Byte (Index));
         Put (Giflib.Byte (Index));
      end loop;
      for Value of Giflib.Streams.Byte_Array'
        ([16#2C#, 0, 0, 0, 0, 64, 0, 64, 0, 0, 8])
      loop
         Put (Value);
      end loop;
      Result (Position .. Position + Data'Length - 1) := Data;
      Position := Position + Data'Length;
      Result (Position) := 16#3B#;
      return Result;
   end Make;
end Giflib_Fuzz_LZW_Stress;
