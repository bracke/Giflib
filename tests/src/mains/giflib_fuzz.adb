with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Giflib.Streams;
with Giflib_Fuzz_Harness;
with Giflib_Fuzz_LZW_Stress;
with Giflib_Fuzz_Mutations;
with Giflib_Fuzz_Seed_Corpus;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Project_Tools.Test_Fixtures;

procedure Giflib_Fuzz is
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

   State : Project_Tools.Test_Fixtures.Deterministic_Seed := 16#C0DEC0DE#;
   Iterations : Positive := 10_000;
begin
   if Ada.Command_Line.Argument_Count > 2 then
      Project_Tools.Release_Checks.Fail ("usage: giflib_fuzz [iterations [seed]]");
   end if;
   if Ada.Command_Line.Argument_Count >= 1 then
      Iterations := Positive'Value (Ada.Command_Line.Argument (1));
   end if;
   if Ada.Command_Line.Argument_Count >= 2 then
      State := Project_Tools.Test_Fixtures.Deterministic_Seed'Value
        (Ada.Command_Line.Argument (2));
   end if;
   declare
      Root : constant String := Find_Repository_Root;
      Literal_Seed : constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_Seed_Corpus.Literal;
      Indexed_Seed : constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_Seed_Corpus.Load
          (Root, "tests/fixtures/generated/imagemagick-indexed.gif");
      Animation_Seed : constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_Seed_Corpus.Load
          (Root, "tests/fixtures/generated/imagemagick-animation.gif");
      External_Seed : constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_Seed_Corpus.Load
          (Root, "tests/fixtures/external/docbook-tip.gif");
      Dictionary_Seed : aliased constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_LZW_Stress.Make (False);
      Expansion_Seed : aliased constant Giflib.Streams.Byte_Array :=
        Giflib_Fuzz_LZW_Stress.Make (True);
      Buffer : aliased Giflib.Streams.Byte_Array :=
        [for I in 1 .. 32_768 => 0];
      Length : Positive;

      procedure Select_Seed (Iteration : Positive) is
      begin
         case (Iteration - 1) mod 6 is
            when 0 =>
               Giflib_Fuzz_Mutations.Copy (Literal_Seed, Buffer, Length);
            when 1 =>
               Giflib_Fuzz_Mutations.Copy (Indexed_Seed, Buffer, Length);
            when 2 =>
               Giflib_Fuzz_Mutations.Copy (Animation_Seed, Buffer, Length);
            when 3 =>
               Giflib_Fuzz_Mutations.Copy (External_Seed, Buffer, Length);
            when 4 =>
               Giflib_Fuzz_Mutations.Copy (Dictionary_Seed, Buffer, Length);
            when others =>
               Giflib_Fuzz_Mutations.Copy (Expansion_Seed, Buffer, Length);
         end case;
      end Select_Seed;
   begin
      if Expansion_Seed'Length >= 1_024 then
         Project_Tools.Release_Checks.Fail
           ("giflib_fuzz: high-expansion seed is not compact");
      end if;
      Giflib_Fuzz_Harness.Verify_Stress_Seed
        (Dictionary_Seed, Uniform => False);
      Giflib_Fuzz_Harness.Verify_Stress_Seed
        (Expansion_Seed, Uniform => True);
      for I in 1 .. Iterations loop
         Select_Seed (I);
         Giflib_Fuzz_Mutations.Apply (I, Buffer, Length, State);
         Giflib_Fuzz_Harness.Exercise (Buffer, Length);
      end loop;
   end;
   Ada.Text_IO.Put_Line
     ("deterministic fuzz completed iterations=" & Positive'Image (Iterations)
      & " final_seed=" & Project_Tools.Test_Fixtures.Seed_Image (State));
end Giflib_Fuzz;
