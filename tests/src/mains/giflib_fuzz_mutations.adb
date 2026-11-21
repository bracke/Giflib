with Giflib;
with Project_Tools.Release_Checks;

package body Giflib_Fuzz_Mutations is
   use type Giflib.Byte;

   procedure Copy
     (Seed : Giflib.Streams.Byte_Array;
      Buffer : in out Giflib.Streams.Byte_Array;
      Length : out Positive) is
   begin
      if Seed'Length = 0
        or else Seed'Length > Buffer'Length
        or else Buffer'Length - Seed'Length < 64
      then
         Project_Tools.Release_Checks.Fail
           ("giflib_fuzz: seed does not fit mutation buffer with required slack");
      end if;
      for I in 0 .. Seed'Length - 1 loop
         Buffer (Buffer'First + I) := Seed (Seed'First + I);
      end loop;
      Length := Seed'Length;
   end Copy;

   procedure Apply
     (Iteration : Positive;
      Buffer : in out Giflib.Streams.Byte_Array;
      Length : in out Positive;
      State : in out Project_Tools.Test_Fixtures.Deterministic_Seed)
   is
      Original_Length : constant Positive := Length;
      Position : Positive;
      Additional : Natural;
      function Next return Natural is
         Value : Natural;
      begin
         Project_Tools.Test_Fixtures.Advance (State, Value);
         return Value;
      end Next;
   begin
      if Length > Buffer'Length then
         Project_Tools.Release_Checks.Fail
           ("giflib_fuzz: mutation length exceeds buffer");
      end if;
      case Iteration mod 5 is
         when 0 => Length := 1 + Next mod Original_Length;
         when 1 =>
            Position := Buffer'First + Next mod Length;
            Buffer (Position) := Buffer (Position) xor Giflib.Byte (Next mod 256);
         when 2 =>
            for Mutation in 1 .. 4 loop
               Position := Buffer'First + Next mod Length;
               Buffer (Position) := Giflib.Byte (Next mod 256);
            end loop;
         when 3 =>
            Additional := 1 + Next mod 64;
            if Additional > Buffer'Length - Length then
               Project_Tools.Release_Checks.Fail
                 ("giflib_fuzz: mutation growth exceeds buffer");
            end if;
            Length := Length + Additional;
            for J in Original_Length + 1 .. Length loop
               Buffer (Buffer'First + J - 1) := Giflib.Byte (Next mod 256);
            end loop;
         when others =>
            if Length = 1 then
               Buffer (Buffer'First) :=
                 Buffer (Buffer'First) xor Giflib.Byte (1 + Next mod 255);
            else
               Position := Buffer'First + Next mod Length;
               for J in Position .. Buffer'First + Length - 2 loop
                  Buffer (J) := Buffer (J + 1);
               end loop;
               Length := Length - 1;
            end if;
      end case;
   end Apply;
end Giflib_Fuzz_Mutations;
