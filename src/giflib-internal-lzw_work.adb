with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.LZW_Work is
   function Try_Charge
     (Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Boolean
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      return Accepted;
   end Try_Charge;

   function Accumulate
     (Work : in out Work_Budgets.Meter;
      Pending : in out Byte_Count;
      Amount : Byte_Count;
      Batch_Size : Byte_Count) return Boolean
   is
      Total : constant Byte_Count := Pending + Amount;
   begin
      if Total >= Batch_Size
        or else not Work_Budgets.Can_Charge (Work, Total)
      then
         if not Try_Charge (Work, Total) then
            return False;
         end if;
         Pending := 0;
      else
         Pending := Total;
      end if;
      return True;
   end Accumulate;

   function Commit
     (Work : in out Work_Budgets.Meter;
      Pending : in out Byte_Count) return Boolean is
   begin
      if Pending = 0 then
         return True;
      elsif not Try_Charge (Work, Pending) then
         return False;
      end if;
      Pending := 0;
      return True;
   end Commit;

   function Failure
     (Source : Streams.Source'Class;
      Work : Work_Budgets.Meter;
      Frame : Frame_Ordinal) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Source
              (Source,
               Resource_Diagnostics.With_Work_Limit
                 (Work, LZW_Work_Limit,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame), others => <>))))));

   function Failure
     (Destination : Streams.Destination'Class;
      Work : Work_Budgets.Meter) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Destination
              (Destination,
               Resource_Diagnostics.With_Work_Limit
                 (Work, LZW_Work_Limit)))));

end Giflib.Internal.LZW_Work;
