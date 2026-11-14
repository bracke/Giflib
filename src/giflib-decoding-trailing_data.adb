with Giflib.Decoding.Failure_Handling;
with Giflib.Internal.Stream_Arithmetic;

package body Giflib.Decoding.Trailing_Data is
   function Validate (Object : in out Decoder) return Results.Result is
      Buffer : Streams.Byte_Array (1 .. 1);
      Step : Streams.Source_Result;
      Position : constant Streams.Source_Position_Result :=
        Failure_Handling.Input_Position_Of (Object);
      Source_Context : constant Errors.Source_Position_Context :=
        (if Position.Available
         then Errors.Source_Position_At (Position.Value)
         else (State => Errors.Position_Unavailable));
   begin
      Step := Streams.Read_Some (Object.Input.all, Buffer);
      if Errors.Is_Fatal (Step.Error) then
         return Results.Failure (Step.Error);
      elsif not Internal.Stream_Arithmetic.Fits_Natural_Remaining
        (0, Buffer'Length, Step.Count)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source_Position => Source_Context,
                Expected => Byte_Count (Buffer'Length),
                Actual => Step.Count,
                others => <>)));
      elsif Step.Count = 0 and then Step.End_Of_Input then
         return Results.Success;
      elsif Step.Count = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Source_Zero_Progress,
               (Source_Position => Source_Context, others => <>)));
      elsif Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Trailing_Data,
               (Source_Position => Source_Context,
                Block => Trailing_Data_Block,
                Expected => 0,
                Actual => Step.Count,
                others => <>)));
      end if;
      Failure_Handling.Record_Warning
        (Object, Errors.Trailing_Data_Ignored, Errors.Compatibility,
         (Source_Position => Source_Context,
          Block => Trailing_Data_Block,
          Actual => Step.Count,
          others => <>));
      return Results.Success;
   end Validate;
end Giflib.Decoding.Trailing_Data;
