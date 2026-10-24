with Ada.Command_Line;
with Ada.Text_IO;

with Giflib;
with Giflib.Decoding;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
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
   Buffer : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   State : Project_Tools.Test_Fixtures.Deterministic_Seed := 16#C0DEC0DE#;
   Iterations : Positive := 10_000;

   function Next return Natural is
      Value : Natural;
   begin
      Project_Tools.Test_Fixtures.Advance (State, Value);
      return Value;
   end Next;

   procedure Exercise (Length : Positive) is
      Input : aliased constant Giflib.Streams.Byte_Array := Buffer (1 .. Length);
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
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
      Giflib.Streams.Open (Source, Input'Unchecked_Access, Max_Transfer => 3);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Constraints => Constraints);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         for Event_Count in 1 .. 64 loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            exit when not Giflib.Results.Succeeded (Outcome)
              or else Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Outcome := Giflib.Decoding.Skip_Frame (Decoder);
               exit when not Giflib.Results.Succeeded (Outcome);
            end if;
         end loop;
      end if;
      Giflib.Decoding.Finalize (Decoder);
   end Exercise;

   Length : Positive;
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
      for J in Seed_GIF'Range loop
         Buffer (J) := Seed_GIF (J);
      end loop;
      Length := Seed_GIF'Length;
      case I mod 5 is
         when 0 =>
            Length := 1 + Next mod Seed_GIF'Length;
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
            for J in Seed_GIF'Length + 1 .. Length loop
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
