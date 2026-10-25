with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Work
  with Preelaborate
is
   function Charge
     (Source : Streams.Source'Class;
      Work : in out Work_Budgets.Meter;
      Frame : Frame_Ordinal;
      Amount : Byte_Count) return Results.Result;

   function Charge
     (Destination : Streams.Destination'Class;
      Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Results.Result;
end Giflib.Internal.LZW_Work;
