package Giflib.Internal.Block_Arithmetic
  with Pure, SPARK_Mode
is
   subtype Sub_Block_Count is Natural range 0 .. 255;
   subtype Positive_Sub_Block_Count is Natural range 1 .. 255;
   subtype Writer_Used is Natural range 0 .. 254;

   type Reader_Transfer is record
      Count : Sub_Block_Count;
      Remaining : Sub_Block_Count;
   end record;

   function Plan_Read
     (Remaining : Sub_Block_Count;
      Requested : Natural) return Reader_Transfer
     with Post =>
       Plan_Read'Result.Count = Natural'Min (Remaining, Requested)
       and then Plan_Read'Result.Remaining =
         Remaining - Plan_Read'Result.Count;

   type Writer_Transfer is record
      Count : Positive_Sub_Block_Count;
      Used : Positive_Sub_Block_Count;
      Position : Positive;
   end record;

   function Plan_Write
     (Used : Writer_Used;
      Position : Natural;
      Length : Positive) return Writer_Transfer
     with Pre => Position < Length,
          Post =>
            Plan_Write'Result.Count =
              Natural'Min (255 - Used, Length - Position)
            and then Plan_Write'Result.Used =
              Used + Plan_Write'Result.Count
            and then Plan_Write'Result.Position =
              Position + Plan_Write'Result.Count
            and then Plan_Write'Result.Used <= 255
            and then Plan_Write'Result.Position <= Length;
end Giflib.Internal.Block_Arithmetic;
