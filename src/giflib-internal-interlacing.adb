package body Giflib.Internal.Interlacing with SPARK_Mode is
   function Rows_In_Pass (Height, Start, Step : Natural) return Natural is
   begin
      if Height <= Start then
         return 0;
      end if;
      return ((Height - 1 - Start) / Step) + 1;
   end Rows_In_Pass;

   function Row_For_Ordinal (Height, Ordinal : Natural) return Natural is
      Remaining : Natural := Ordinal;
      Count : Natural;
      Starts : constant array (Positive range 1 .. 4) of Natural := [0, 4, 2, 1];
      Steps : constant array (Positive range 1 .. 4) of Positive := [8, 8, 4, 2];
   begin
      if Height = 0 or else Ordinal >= Height then
         return Height;
      end if;
      for Pass in Starts'Range loop
         Count := Rows_In_Pass (Height, Starts (Pass), Steps (Pass));
         if Remaining < Count then
            return Starts (Pass) + Remaining * Steps (Pass);
         end if;
         Remaining := Remaining - Count;
      end loop;
      return Height;
   end Row_For_Ordinal;
end Giflib.Internal.Interlacing;
