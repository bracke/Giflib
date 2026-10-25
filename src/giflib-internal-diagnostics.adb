package body Giflib.Internal.Diagnostics is
   use type Errors.Position_State;

   function At_Source
     (Object : Streams.Source'Class;
      Context : Errors.Diagnostic_Context := (others => <>);
      Rewind : Source_Offset := 0) return Errors.Diagnostic_Context
   is
   begin
      if Context.Source_Position.State /= Errors.Position_Not_Checked then
         return Context;
      end if;
      return With_Source (Context, Streams.Position (Object, Rewind));
   end At_Source;

   function At_Destination
     (Object : Streams.Destination'Class;
      Context : Errors.Diagnostic_Context := (others => <>))
      return Errors.Diagnostic_Context
   is
   begin
      if Context.Destination_Position.State /= Errors.Position_Not_Checked then
         return Context;
      end if;
      return With_Destination (Context, Streams.Position (Object));
   end At_Destination;

   function With_Source
     (Context : Errors.Diagnostic_Context;
      Position : Streams.Source_Position_Result)
      return Errors.Diagnostic_Context
   is
      Result : Errors.Diagnostic_Context := Context;
   begin
      Result.Source_Position :=
        (if Position.Available
         then Errors.Source_Position_At (Position.Value)
         else (State => Errors.Position_Unavailable));
      return Result;
   end With_Source;

   function With_Destination
     (Context : Errors.Diagnostic_Context;
      Position : Streams.Destination_Position_Result)
      return Errors.Diagnostic_Context
   is
      Result : Errors.Diagnostic_Context := Context;
   begin
      Result.Destination_Position :=
        (if Position.Available
         then Errors.Destination_Position_At (Position.Value)
         else (State => Errors.Position_Unavailable));
      return Result;
   end With_Destination;

   function Rewind
     (Position : Streams.Source_Position_Result;
      Amount : Source_Offset) return Streams.Source_Position_Result
   is
   begin
      if not Position.Available or else Position.Value < Amount then
         return (Available => False);
      end if;
      return (Available => True, Value => Position.Value - Amount);
   end Rewind;

end Giflib.Internal.Diagnostics;
