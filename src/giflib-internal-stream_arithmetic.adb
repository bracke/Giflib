package body Giflib.Internal.Stream_Arithmetic
  with SPARK_Mode
is
   function Cap_To_Natural (Value : Byte_Count) return Natural is
     (if Value > Byte_Count (Natural'Last)
      then Natural'Last
      else Natural (Value));

   function Plan_Transfer
     (Position : Natural;
      Length : Natural;
      Requested : Natural;
      Maximum : Byte_Count) return Transfer_Plan
   is
      Available : constant Natural := Length - Position;
      Count : constant Natural :=
        Natural'Min
          (Natural'Min (Requested, Available), Cap_To_Natural (Maximum));
   begin
      return
        (Available => Available,
         Count => Count,
         Next_Position => Position + Count);
   end Plan_Transfer;

   function Fits_Natural_Remaining
     (Completed : Natural;
      Total : Natural;
      Step : Byte_Count) return Boolean
   is (Step <= Byte_Count (Total - Completed));

   function Advance_Natural
     (Completed : Natural;
      Total : Natural;
      Step : Byte_Count) return Natural
   is
      pragma Unreferenced (Total);
   begin
      return Completed + Natural (Step);
   end Advance_Natural;

   function Fits_Count_Remaining
     (Completed : Byte_Count;
      Total : Byte_Count;
      Step : Byte_Count) return Boolean
   is (Step <= Total - Completed);

   function Advance_Count
     (Completed : Byte_Count;
      Total : Byte_Count;
      Step : Byte_Count) return Byte_Count
   is
      pragma Unreferenced (Total);
   begin
      return Completed + Step;
   end Advance_Count;
end Giflib.Internal.Stream_Arithmetic;
