with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Interlacing;

package body Giflib.Internal.LZW_Encoding is
   use type Interfaces.Unsigned_32;

   function Encode
     (Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
      Hash_Size : constant := 8_192;
      type Natural_Table is array (Natural range 0 .. Hash_Size - 1) of Natural;
      type Byte_Table is array (Natural range 0 .. Hash_Size - 1) of Byte;
      type Boolean_Table is array (Natural range 0 .. Hash_Size - 1) of Boolean;
      Prefix_Key : Natural_Table := [others => 0];
      Suffix_Key : Byte_Table := [others => 0];
      Code_Value : Natural_Table := [others => 0];
      Used : Boolean_Table := [others => False];
      Writer : Blocks.Sub_Block_Writer;
      Bits : Interfaces.Unsigned_32 := 0;
      Bit_Count : Natural := 0;
      Width : Natural;
      Clear_Code : Natural;
      End_Code : Natural;
      Next_Free : Natural;
      Work : Byte_Count := 0;

      function Charge (Amount : Byte_Count) return Results.Result is
      begin
         if Work > Max_Work or else Amount > Max_Work - Work then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Destination => Object.Offset,
                   Expected => Max_Work,
                   Actual => Work + Amount,
                   Limit => LZW_Work_Limit,
                   others => <>)));
         end if;
         Work := Work + Amount;
         return Results.Success;
      end Charge;

      function Put_Code (Code : Natural) return Results.Result is
         One : Streams.Byte_Array (1 .. 1);
         Outcome : Results.Result;
      begin
         Outcome := Charge (1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Bits := Bits or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Code), Bit_Count);
         Bit_Count := Bit_Count + Width;
         while Bit_Count >= 8 loop
            One (1) := Byte (Bits and 16#FF#);
            Outcome := Blocks.Write_Data (Writer, Object, One);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            Bits := Interfaces.Shift_Right (Bits, 8);
            Bit_Count := Bit_Count - 8;
         end loop;
         return Results.Success;
      end Put_Code;

      procedure Clear_Dictionary is
      begin
         Used := [others => False];
         Next_Free := Clear_Code + 2;
         Width := Natural (Minimum_Code_Size) + 1;
      end Clear_Dictionary;

      function Find
        (Prefix : Natural;
         Suffix : Byte;
         Found : out Boolean;
         Slot : out Natural) return Results.Result
      is
         Position : Natural := (Prefix * 257 + Natural (Suffix)) mod Hash_Size;
         Outcome : Results.Result;
      begin
         loop
            Outcome := Charge (1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            if not Used (Position) then
               Found := False;
               Slot := Position;
               return Results.Success;
            elsif Prefix_Key (Position) = Prefix and then Suffix_Key (Position) = Suffix then
               Found := True;
               Slot := Position;
               return Results.Success;
            end if;
            Position := (Position + 1) mod Hash_Size;
         end loop;
      end Find;

      function Input_At (Ordinal : Natural) return Byte is
         Position : Natural := Ordinal;
      begin
         if Interlace_Width > 0 then
            Position :=
              Interlacing.Row_For_Ordinal (Interlace_Height, Ordinal / Interlace_Width)
              * Interlace_Width + Ordinal mod Interlace_Width;
         end if;
         return Input (Input'First + Position);
      end Input_At;

      Prefix : Natural;
      Suffix : Byte;
      Found : Boolean;
      Slot : Natural;
      Outcome : Results.Result;
      One : Streams.Byte_Array (1 .. 1);
   begin
      Compressed_Bytes := 0;
      if Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Results.Failure (Errors.Make (Errors.LZW_Invalid_Minimum_Code_Size));
      elsif Input'Length = 0 then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
      elsif Interlace_Width > 0
        and then (Interlace_Height = 0
                  or else Interlace_Width > Natural'Last / Interlace_Height
                  or else Interlace_Width * Interlace_Height /= Input'Length)
      then
         return Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Clear_Code := 2 ** Natural (Minimum_Code_Size);
      End_Code := Clear_Code + 1;
      Blocks.Initialize (Writer, Max_Compressed_Bytes, Max_Wire_Bytes);
      Clear_Dictionary;
      Outcome := Put_Code (Clear_Code);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Prefix := Natural (Input_At (0));
      for I in 1 .. Input'Length - 1 loop
         Suffix := Input_At (I);
         Outcome := Find (Prefix, Suffix, Found, Slot);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Found then
            Prefix := Code_Value (Slot);
         else
            Outcome := Put_Code (Prefix);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            if Next_Free < 4_096 then
               Used (Slot) := True;
               Prefix_Key (Slot) := Prefix;
               Suffix_Key (Slot) := Suffix;
               Code_Value (Slot) := Next_Free;
               Next_Free := Next_Free + 1;
               if Next_Free > 2 ** Width and then Width < 12 then
                  Width := Width + 1;
               end if;
            else
               Outcome := Put_Code (Clear_Code);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Outcome := Charge (Hash_Size);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Clear_Dictionary;
            end if;
            Prefix := Natural (Suffix);
         end if;
      end loop;
      Outcome := Put_Code (Prefix);
      if Results.Succeeded (Outcome) then
         Outcome := Put_Code (End_Code);
      end if;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Bit_Count > 0 then
         One (1) := Byte (Bits and 16#FF#);
         Outcome := Blocks.Write_Data (Writer, Object, One);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;
      Outcome := Blocks.Finish (Writer, Object);
      Compressed_Bytes := Blocks.Total_Payload_Bytes (Writer);
      return Outcome;
   end Encode;
end Giflib.Internal.LZW_Encoding;
