separate (Giflib.Testing.Test_Streams)
procedure Callback_Exceptions_Are_Normalized
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Source : Raising_Source;
   Destination : Raising_Destination;
   Buffer : Giflib.Streams.Byte_Array (1 .. 1);
   Outcome : Giflib.Results.Result;
   Flush_Error : Giflib.Errors.Error;
begin
   Outcome := Giflib.Streams.Read_Exact (Source, Buffer);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed,
      "raising source read escaped the stream facade");
   Outcome := Giflib.Streams.Skip_Exact (Source, 1);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed,
      "raising source skip escaped the stream facade");
   Assert
     (not Giflib.Streams.Position (Source).Available,
      "raising source offset was reported as available");
   Outcome := Giflib.Streams.Write_All (Destination, [1 => 1]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
      "raising destination write escaped the stream facade");
   Assert
     (not Giflib.Streams.Position (Destination).Available,
      "raising destination offset was reported as available");
   Flush_Error := Giflib.Streams.Flush_Safely (Destination);
   Assert
     (Flush_Error.Code = Giflib.Errors.Destination_Write_Failed,
      "raising destination flush escaped the stream facade");
end Callback_Exceptions_Are_Normalized;
