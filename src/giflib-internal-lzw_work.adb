with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.LZW_Work is
   function Charge
     (Source : Streams.Source'Class;
      Work : in out Work_Budgets.Meter;
      Frame : Frame_Ordinal;
      Amount : Byte_Count) return Results.Result
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      if Accepted then
         return Results.Success;
      end if;
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Source
              (Source,
               Resource_Diagnostics.With_Work_Limit
                 (Work, LZW_Work_Limit,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame), others => <>)))));
   end Charge;

   function Charge
     (Destination : Streams.Destination'Class;
      Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Results.Result
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      if Accepted then
         return Results.Success;
      end if;
      return Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Diagnostics.At_Destination
              (Destination,
               Resource_Diagnostics.With_Work_Limit
                 (Work, LZW_Work_Limit))));
   end Charge;
end Giflib.Internal.LZW_Work;
