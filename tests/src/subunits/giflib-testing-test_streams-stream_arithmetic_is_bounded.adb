separate (Giflib.Testing.Test_Streams)
procedure Stream_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Stream_Arithmetic;
   Ordinary : constant Arithmetic.Transfer_Plan :=
     Arithmetic.Plan_Transfer (Position => 3, Length => 10, Requested => 6, Maximum => 4);
   Edge : constant Arithmetic.Transfer_Plan :=
     Arithmetic.Plan_Transfer
       (Position => Natural'Last - 1,
        Length => Natural'Last,
        Requested => Natural'Last,
        Maximum => Giflib.Byte_Count'Last);
begin
   Assert
     (Ordinary.Available = 7
      and then Ordinary.Count = 4
      and then Ordinary.Next_Position = 7,
      "ordinary transfer plan is wrong");
   Assert
     (Edge.Available = 1
      and then Edge.Count = 1
      and then Edge.Next_Position = Natural'Last,
      "maximum-position transfer plan overflowed");
   Assert
     (Arithmetic.Fits_Natural_Remaining (8, 10, 2)
      and then not Arithmetic.Fits_Natural_Remaining (8, 10, 3)
      and then Arithmetic.Advance_Natural (8, 10, 2) = 10,
      "natural progress accounting is wrong");
   Assert
     (Arithmetic.Fits_Count_Remaining
        (Giflib.Byte_Count'Last - 5, Giflib.Byte_Count'Last, 5)
      and then Arithmetic.Advance_Count
        (Giflib.Byte_Count'Last - 5, Giflib.Byte_Count'Last, 5)
          = Giflib.Byte_Count'Last,
      "byte-count progress accounting overflowed");
end Stream_Arithmetic_Is_Bounded;

