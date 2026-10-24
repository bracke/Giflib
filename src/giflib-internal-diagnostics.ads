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
end Giflib.Internal.Diagnostics;
