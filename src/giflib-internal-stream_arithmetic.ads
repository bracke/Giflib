package Giflib.Internal.Stream_Arithmetic
  with Pure, SPARK_Mode
is
   function Cap_To_Natural (Value : Byte_Count) return Natural
     with Post =>
       Cap_To_Natural'Result =
         (if Value > Byte_Count (Natural'Last)
          then Natural'Last
          else Natural (Value));

   type Transfer_Plan is record
      Available : Natural;
      Count : Natural;
      Next_Position : Natural;
   end record;

   function Plan_Transfer
     (Position : Natural;
      Length : Natural;
      Requested : Natural;
      Maximum : Byte_Count) return Transfer_Plan
     with Pre => Position <= Length,
          Post =>
            Plan_Transfer'Result.Available = Length - Position
            and then Plan_Transfer'Result.Count =
              Natural'Min
                (Natural'Min (Requested, Length - Position),
                 Cap_To_Natural (Maximum))
            and then Plan_Transfer'Result.Next_Position =
              Position + Plan_Transfer'Result.Count
            and then Plan_Transfer'Result.Next_Position <= Length;

   function Fits_Natural_Remaining
     (Completed : Natural;
      Total : Natural;
      Step : Byte_Count) return Boolean
     with Pre => Completed <= Total,
          Post =>
            Fits_Natural_Remaining'Result =
              (Step <= Byte_Count (Total - Completed));

   function Advance_Natural
     (Completed : Natural;
      Total : Natural;
      Step : Byte_Count) return Natural
     with Pre =>
            Completed <= Total
            and then Step > 0
            and then Fits_Natural_Remaining (Completed, Total, Step),
          Post =>
            Advance_Natural'Result = Completed + Natural (Step)
            and then Advance_Natural'Result <= Total;

   function Fits_Count_Remaining
     (Completed : Byte_Count;
      Total : Byte_Count;
      Step : Byte_Count) return Boolean
     with Pre => Completed <= Total,
          Post =>
            Fits_Count_Remaining'Result = (Step <= Total - Completed);

   function Advance_Count
     (Completed : Byte_Count;
      Total : Byte_Count;
      Step : Byte_Count) return Byte_Count
     with Pre =>
            Completed <= Total
            and then Step > 0
            and then Fits_Count_Remaining (Completed, Total, Step),
          Post =>
            Advance_Count'Result = Completed + Step
            and then Advance_Count'Result <= Total;
end Giflib.Internal.Stream_Arithmetic;
