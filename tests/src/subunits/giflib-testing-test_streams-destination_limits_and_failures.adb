separate (Giflib.Testing.Test_Streams)
procedure Destination_Limits_And_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [1, 2, 3, 4];
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0];
   Roomy : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Roomy_Destination : Giflib.Streams.Fixed_Buffer_Destination (Roomy'Access);
   Failed_Destination : Raising_Destination;
   Outcome : Giflib.Results.Result;
   Written : Giflib.Byte_Count;
begin
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Streams.Write_All (Destination, Input, Written);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "fixed-buffer overflow has wrong error");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit, "output limit context was lost");
   Assert (Destination.Offset = 2 and then Written = 2,
           "partial failure byte count is wrong");

   Giflib.Streams.Open (Roomy_Destination, Max_Transfer => 0);
   Outcome := Giflib.Streams.Write_All (Roomy_Destination, Input);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Zero_Progress,
           "zero-progress write was not rejected");
   Assert
     (Outcome.First_Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      and then Outcome.First_Error.Context.Destination_Position.Value = 0,
      "zero destination offset was not preserved as present");

   Outcome := Giflib.Streams.Write_All (Failed_Destination, Input);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
           "destination failure was not propagated");
end Destination_Limits_And_Failures;

