package body Giflib.Internal.Block_Arithmetic
  with SPARK_Mode
is
   function Plan_Read
     (Remaining : Sub_Block_Count;
      Requested : Natural) return Reader_Transfer
   is
      Count : constant Sub_Block_Count := Natural'Min (Remaining, Requested);
   begin
      return (Count => Count, Remaining => Remaining - Count);
   end Plan_Read;

   function Plan_Write
     (Used : Writer_Used;
      Position : Natural;
      Length : Positive) return Writer_Transfer
   is
      Count : constant Positive_Sub_Block_Count :=
        Natural'Min (255 - Used, Length - Position);
   begin
      return
        (Count => Count,
         Used => Used + Count,
         Position => Position + Count);
   end Plan_Write;
end Giflib.Internal.Block_Arithmetic;
