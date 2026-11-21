with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Work
  with Preelaborate
is
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   function Try_Charge
     (Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Boolean;

   function Accumulate
     (Work : in out Work_Budgets.Meter;
      Pending : in out Byte_Count;
      Amount : Byte_Count;
      Batch_Size : Byte_Count) return Boolean
     with Pre => Batch_Size > 0
                 and then Amount <= Byte_Count'Last - Pending;

   function Commit
     (Work : in out Work_Budgets.Meter;
      Pending : in out Byte_Count) return Boolean;

   pragma Inline_Always (Try_Charge);
   pragma Inline_Always (Accumulate);
   pragma Inline_Always (Commit);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");

   function Failure
     (Source : Streams.Source'Class;
      Work : Work_Budgets.Meter;
      Frame : Frame_Ordinal) return Results.Result;

   function Failure
     (Destination : Streams.Destination'Class;
      Work : Work_Budgets.Meter) return Results.Result;

end Giflib.Internal.LZW_Work;
