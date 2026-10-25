separate (Giflib.Testing.Test_Streams)
procedure Callback_Errors_Are_Decorated
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Returned_Source : Error_Source;
   Returned_Destination : Error_Destination;
   Buffer : Giflib.Streams.Byte_Array (1 .. 1);
   Source_Step : Giflib.Streams.Source_Result;
   Destination_Step : Giflib.Streams.Destination_Result;
   Flush_Error : Giflib.Errors.Error;
begin
   Source_Step := Giflib.Streams.Read_Some (Returned_Source, Buffer);
   Assert
     (Source_Step.Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Source_Step.Error.Context.Source_Position.Value = 31,
      "source callback error did not receive its captured position");
   Source_Step := Giflib.Streams.Skip_Some (Returned_Source, 1);
   Assert
     (Source_Step.Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Source_Step.Error.Context.Source_Position.Value = 7,
      "source callback position overwrote existing diagnostic context");
   Destination_Step := Giflib.Streams.Write_Some
     (Returned_Destination, [1 => 1]);
   Assert
     (Destination_Step.Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      and then Destination_Step.Error.Context.Destination_Position.Value = 41,
      "destination callback error did not receive its captured position");
   Flush_Error := Giflib.Streams.Flush_Safely (Returned_Destination);
   Assert
     (Flush_Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      and then Flush_Error.Context.Destination_Position.Value = 8,
      "flush callback position overwrote existing diagnostic context");
end Callback_Errors_Are_Decorated;
