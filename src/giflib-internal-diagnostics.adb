package body Giflib.Internal.Diagnostics is
   function At_Source
     (Object : Streams.Source'Class;
      Context : Errors.Diagnostic_Context := (others => <>);
      Rewind : Source_Offset := 0) return Errors.Diagnostic_Context
   is
      Result : Errors.Diagnostic_Context := Context;
      Position : constant Streams.Source_Position_Result :=
        Streams.Position (Object, Rewind);
   begin
      Result.Has_Source := Position.Available;
      Result.Source := Position.Value;
      return Result;
   end At_Source;

   function At_Destination
     (Object : Streams.Destination'Class;
      Context : Errors.Diagnostic_Context := (others => <>))
      return Errors.Diagnostic_Context
   is
      Result : Errors.Diagnostic_Context := Context;
      Position : constant Streams.Destination_Position_Result :=
        Streams.Position (Object);
   begin
      Result.Has_Destination := Position.Available;
      Result.Destination := Position.Value;
      return Result;
   end At_Destination;
end Giflib.Internal.Diagnostics;
