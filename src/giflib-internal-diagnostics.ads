with Giflib.Errors;
with Giflib.Streams;

package Giflib.Internal.Diagnostics is
   pragma Preelaborate;
   function At_Source
     (Object : Streams.Source'Class;
      Context : Errors.Diagnostic_Context := (others => <>);
      Rewind : Source_Offset := 0) return Errors.Diagnostic_Context;

   function At_Destination
     (Object : Streams.Destination'Class;
      Context : Errors.Diagnostic_Context := (others => <>))
      return Errors.Diagnostic_Context;

   function With_Source
     (Context : Errors.Diagnostic_Context;
      Position : Streams.Source_Position_Result)
      return Errors.Diagnostic_Context;

   function With_Destination
     (Context : Errors.Diagnostic_Context;
      Position : Streams.Destination_Position_Result)
      return Errors.Diagnostic_Context;

   function Rewind
     (Position : Streams.Source_Position_Result;
      Amount : Source_Offset) return Streams.Source_Position_Result;

end Giflib.Internal.Diagnostics;
