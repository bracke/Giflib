with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Giflib;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Project_Tools.Test_Fixtures;

procedure Giflib_Fuzz is
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Byte;

   Seed_GIF : constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97,
      2, 0, 1, 0, 16#80#, 0, 0,
      0, 0, 0, 255, 255, 255,
      16#21#, 16#F9#, 4, 1, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0,
      2, 2, 16#44#, 16#0A#, 0, 16#3B#];
   function Find_Repository_Root return String is
      Result : constant String := Project_Tools.Files.Find_Root_Upward
        (Ada.Directories.Current_Directory, "giflib.gpr");
   begin
      if Result = "" then
         Project_Tools.Release_Checks.Fail
           ("giflib_fuzz: run from within the giflib source tree");
      end if;
      return Result;
   end Find_Repository_Root;

   Root : constant String := Find_Repository_Root;

   function Load_Seed (Relative_Path : String) return Giflib.Streams.Byte_Array is
      Raw : constant String := Project_Tools.Files.Read_Raw_File
        (Project_Tools.Files.Join (Root, Relative_Path));
      Result : Giflib.Streams.Byte_Array (1 .. Raw'Length);
   begin
      for I in Raw'Range loop
         Result (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
      end loop;
      return Result;
   end Load_Seed;

   function Forces_Dictionary_Reset
     (Pixels : Giflib.Streams.Byte_Array) return Boolean
   is
      type Prefix_Table is array (Natural range 258 .. 4_095) of Natural;
      type Suffix_Table is array (Natural range 258 .. 4_095) of Giflib.Byte;
      Prefixes : Prefix_Table := [others => 0];
      Suffixes : Suffix_Table := [others => 0];
      Next_Free : Natural := 258;
      Prefix : Natural := Natural (Pixels (Pixels'First));
      Found : Boolean;
   begin
      for Position in Pixels'First + 1 .. Pixels'Last loop
         Found := False;
         for Code in 258 .. Next_Free - 1 loop
            if Prefixes (Code) = Prefix and then Suffixes (Code) = Pixels (Position) then
               Prefix := Code;
               Found := True;
               exit;
            end if;
         end loop;
         if not Found then
            if Next_Free = 4_096 then
               return True;
            end if;
            Prefixes (Next_Free) := Prefix;
            Suffixes (Next_Free) := Pixels (Position);
            Next_Free := Next_Free + 1;
            Prefix := Natural (Pixels (Position));
         end if;
      end loop;
      return False;
   end Forces_Dictionary_Reset;

   function Make_LZW_Stress_Seed (Uniform : Boolean) return Giflib.Streams.Byte_Array is
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 16_384 => 0];
      Pixels : Giflib.Streams.Byte_Array (1 .. 4_096);
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      Palette : Giflib.Palettes.Palette;
      Local_State : Project_Tools.Test_Fixtures.Deterministic_Seed := 16#5EED1234#;
      Value : Natural;
      Outcome : Giflib.Results.Result;

      procedure Require (Operation : String) is
      begin
         if not Giflib.Results.Succeeded (Outcome) then
            Project_Tools.Release_Checks.Fail
              ("giflib_fuzz: could not build " & Operation & " seed");
         end if;
      end Require;
   begin
      Palette.Length := 256;
      for I in Giflib.Palette_Index loop
         Palette.Colors (I) := (Giflib.Byte (I), Giflib.Byte (I), Giflib.Byte (I));
      end loop;
      for I in Pixels'Range loop
         if Uniform then
            Pixels (I) := 0;
         else
            Project_Tools.Test_Fixtures.Advance (Local_State, Value);
            --  Mixing the upper PRNG bits avoids the 256-byte period of the
            --  low byte alone. This 4,096-byte stream fills and resets the GIF
            --  LZW dictionary before the end code.
            Pixels (I) := Giflib.Byte ((Value + Value / 256) mod 256);
         end if;
      end loop;
      if not Uniform and then not Forces_Dictionary_Reset (Pixels) then
         Project_Tools.Release_Checks.Fail
           ("giflib_fuzz: dictionary stress seed does not reach a reset");
      end if;
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize (Encoder);
      Require ("LZW stress initialization");
      Outcome := Giflib.Encoding.Define_Screen
        (Encoder, (Width => 64, Height => 64, others => <>));
      Require ("LZW stress screen");
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, Palette);
      Require ("LZW stress palette");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder,
         (Width => 64, Height => 64, others => <>),
         Giflib.Encoding.Global_Frame_Palette,
         Pixels);
      Require ("LZW stress frame");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Require ("LZW stress completion");
      return Storage (1 .. Natural (Destination.Offset));
   end Make_LZW_Stress_Seed;

   Indexed_Seed : constant Giflib.Streams.Byte_Array :=
     Load_Seed ("tests/fixtures/generated/imagemagick-indexed.gif");
   Animation_Seed : constant Giflib.Streams.Byte_Array :=
     Load_Seed ("tests/fixtures/generated/imagemagick-animation.gif");
   External_Seed : constant Giflib.Streams.Byte_Array :=
     Load_Seed ("tests/fixtures/external/docbook-tip.gif");
   Dictionary_Seed : constant Giflib.Streams.Byte_Array := Make_LZW_Stress_Seed (False);
   Expansion_Seed : constant Giflib.Streams.Byte_Array := Make_LZW_Stress_Seed (True);

   Buffer : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 32_768 => 0];
   State : Project_Tools.Test_Fixtures.Deterministic_Seed := 16#C0DEC0DE#;
   Iterations : Positive := 10_000;

   function Next return Natural is
      Value : Natural;
   begin
      Project_Tools.Test_Fixtures.Advance (State, Value);
      return Value;
   end Next;

   procedure Copy_Seed
     (Seed : Giflib.Streams.Byte_Array;
      Length : out Positive)
   is
   begin
      if Seed'Length + 64 > Buffer'Length then
         Project_Tools.Release_Checks.Fail ("giflib_fuzz: seed exceeds mutation buffer");
      end if;
      for I in 0 .. Seed'Length - 1 loop
         Buffer (Buffer'First + I) := Seed (Seed'First + I);
      end loop;
      Length := Seed'Length;
   end Copy_Seed;

   procedure Exercise (Length : Positive) is
      Input : aliased constant Giflib.Streams.Byte_Array := Buffer (1 .. Length);
      Source : aliased Giflib.Streams.Memory_Source (Input'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Constraints.Max_Logical_Width := 64;
      Constraints.Max_Logical_Height := 64;
      Constraints.Max_Canvas_Pixels := 4_096;
      Constraints.Max_Canvas_Bytes := 16_384;
      Constraints.Max_Frame_Pixels := 4_096;
      Constraints.Max_Total_Decoded_Frame_Pixels := 16_384;
      Constraints.Max_Compressed_Bytes := 16_384;
      Constraints.Max_Extensions := 32;
      Constraints.Max_Per_Extension_Bytes := 4_096;
      Constraints.Max_Retained_Metadata_Bytes := 4_096;
      Constraints.Max_Allocation_Bytes := 65_536;
      Constraints.Max_LZW_Work := 65_536;
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Giflib.Streams.Open (Source, Max_Transfer => 3);
      Outcome := Giflib.Decoding.Initialize
        (Decoder, Options, Constraints);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         declare
            Canvas : Giflib.Streams.Byte_Array
              (1 .. Natural (Header.Width) * Natural (Header.Height) * 4);
            Info : Giflib.Decoding.Frame_Info;
         begin
            for Event_Count in 1 .. 64 loop
               Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
               exit when not Giflib.Results.Succeeded (Outcome)
                 or else Event.Kind = Giflib.Decoding.End_Event;
               if Event.Kind = Giflib.Decoding.Image_Event then
                  Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
                  exit when not Giflib.Results.Succeeded (Outcome);
               end if;
            end loop;
         end;
      end if;
      Giflib.Decoding.Finalize (Decoder);
   end Exercise;

   Length : Positive;
   Original_Length : Positive;
   Position : Positive;
begin
   if Ada.Command_Line.Argument_Count > 2 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_fuzz [iterations [seed]]");
   end if;
   if Ada.Command_Line.Argument_Count >= 1 then
      Iterations := Positive'Value (Ada.Command_Line.Argument (1));
   end if;
   if Ada.Command_Line.Argument_Count >= 2 then
      State := Project_Tools.Test_Fixtures.Deterministic_Seed'Value
        (Ada.Command_Line.Argument (2));
   end if;
   for I in 1 .. Iterations loop
      case (I - 1) mod 6 is
         when 0 => Copy_Seed (Seed_GIF, Length);
         when 1 => Copy_Seed (Indexed_Seed, Length);
         when 2 => Copy_Seed (Animation_Seed, Length);
         when 3 => Copy_Seed (External_Seed, Length);
         when 4 => Copy_Seed (Dictionary_Seed, Length);
         when others => Copy_Seed (Expansion_Seed, Length);
      end case;
      Original_Length := Length;
      case I mod 5 is
         when 0 =>
            Length := 1 + Next mod Original_Length;
         when 1 =>
            Position := 1 + Next mod Length;
            Buffer (Position) := Buffer (Position) xor Giflib.Byte (Next mod 256);
         when 2 =>
            for Mutation in 1 .. 4 loop
               Position := 1 + Next mod Length;
               Buffer (Position) := Giflib.Byte (Next mod 256);
            end loop;
         when 3 =>
            Length := Length + 1 + Next mod 64;
            for J in Original_Length + 1 .. Length loop
               Buffer (J) := Giflib.Byte (Next mod 256);
            end loop;
         when others =>
            Position := 1 + Next mod Length;
            for J in Position .. Length - 1 loop
               Buffer (J) := Buffer (J + 1);
            end loop;
            Length := Length - 1;
      end case;
      Exercise (Length);
   end loop;
   Ada.Text_IO.Put_Line
     ("deterministic fuzz completed iterations=" & Positive'Image (Iterations)
      & " final_seed=" & Project_Tools.Test_Fixtures.Seed_Image (State));
end Giflib_Fuzz;
