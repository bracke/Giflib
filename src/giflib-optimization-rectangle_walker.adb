with Giflib.Errors;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Optimization.Rectangle_Walker is
   function Walk
     (Work : in out Internal.Work_Budgets.Meter;
      Left : Natural;
      Top : Natural;
      Width : Natural;
      Height : Natural;
      Canvas_Width : Image_Width)
      return Results.Result
   is
      Accepted : Boolean;
      Position : Natural;
   begin
      if Width = 0 or else Height = 0 then return Results.Success; end if;
      for Y in Top .. Top + Height - 1 loop
         Internal.Work_Budgets.Try_Charge
           (Work, Byte_Count (Width), Accepted);
         if not Accepted then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Internal.Resource_Diagnostics.With_Work_Limit
                    (Work, Optimization_Work_Limit)));
         end if;
         Position := Natural
           (Internal.Pixel_Arithmetic.Pixel_Index (Left, Y, Canvas_Width));
         for X in Left .. Left + Width - 1 loop
            if Visit (X, Y, Position) = Stop_Visit then
               return Results.Success;
            end if;
            Position := Position + 1;
         end loop;
      end loop;
      return Results.Success;
   end Walk;
end Giflib.Optimization.Rectangle_Walker;
