package body Giflib.Internal.Interlacing with SPARK_Mode is
   function Rows_In_Pass (Height, Start, Step : Natural) return Natural
     with Pre => Height <= 65_535 and then Start <= 4 and then Step in 2 .. 8,
          Post =>
            (if Height <= Start then
                Rows_In_Pass'Result = 0
             else
                Rows_In_Pass'Result > 0
                and then Rows_In_Pass'Result <= Height
                and then Start + (Rows_In_Pass'Result - 1) * Step < Height)
   is
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
         pragma Loop_Invariant (Remaining < Height);
         Count := Rows_In_Pass (Height, Starts (Pass), Steps (Pass));
         if Remaining < Count then
            pragma Assert
              (Starts (Pass) + Remaining * Steps (Pass) < Height);
            return Starts (Pass) + Remaining * Steps (Pass);
         end if;
         Remaining := Remaining - Count;
      end loop;
      return Height;
   end Row_For_Ordinal;
end Giflib.Internal.Interlacing;
