package body Giflib.Internal.Stream_Dispatch is
   use type Errors.Position_State;

   function Source_Context
     (Position : Streams.Source_Position_Result)
      return Errors.Source_Position_Context is
     (if Position.Available
      then Errors.Source_Position_At (Position.Value)
      else (State => Errors.Position_Unavailable));

   function Destination_Context
     (Position : Streams.Destination_Position_Result)
      return Errors.Destination_Position_Context is
     (if Position.Available
      then Errors.Destination_Position_At (Position.Value)
      else (State => Errors.Position_Unavailable));

   function Position
     (Object : Streams.Source'Class) return Streams.Source_Position_Result is
   begin
      return (Available => True, Value => Object.Offset);
   exception
      when others => return (Available => False);
   end Position;

   function Position
     (Object : Streams.Source'Class;
      Rewind : Source_Offset) return Streams.Source_Position_Result
   is
      Current : constant Streams.Source_Position_Result := Position (Object);
   begin
      if not Current.Available or else Current.Value < Rewind then
         return (Available => False);
      end if;
      return (Available => True, Value => Current.Value - Rewind);
   end Position;

   function Position
     (Object : Streams.Destination'Class)
      return Streams.Destination_Position_Result is
   begin
      return (Available => True, Value => Object.Offset);
   exception
      when others => return (Available => False);
   end Position;

   function At_Source
     (Item : Errors.Error;
      Position : Streams.Source_Position_Result) return Errors.Error
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Source_Position.State = Errors.Position_Not_Checked then
         Enriched.Context.Source_Position := Source_Context (Position);
      end if;
      return Enriched;
   end At_Source;

   function At_Destination
     (Item : Errors.Error;
      Position : Streams.Destination_Position_Result) return Errors.Error
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Destination_Position.State = Errors.Position_Not_Checked
      then
         Enriched.Context.Destination_Position := Destination_Context (Position);
      end if;
      return Enriched;
   end At_Destination;

   function Read_Some
     (Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array;
      Start : out Streams.Source_Position_Result) return Streams.Source_Result
   is
      Result : Streams.Source_Result;
   begin
      Start := Position (Object);
      Result := Object.Read (Buffer);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Source (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return (Error => At_Source
                   (Errors.Make (Errors.Source_Read_Failed), Start),
                 Count => 0, End_Of_Input => False);
   end Read_Some;

   function Skip_Some
     (Object : in out Streams.Source'Class;
      Count : Byte_Count;
      Start : out Streams.Source_Position_Result) return Streams.Source_Result
   is
      Result : Streams.Source_Result;
   begin
      Start := Position (Object);
      Result := Object.Skip (Count);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Source (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return (Error => At_Source
                   (Errors.Make (Errors.Source_Read_Failed), Start),
                 Count => 0, End_Of_Input => False);
   end Skip_Some;

   function Write_Some
     (Object : in out Streams.Destination'Class;
      Buffer : Streams.Byte_Array;
      Start : out Streams.Destination_Position_Result)
      return Streams.Destination_Result
   is
      Result : Streams.Destination_Result;
   begin
      Start := Position (Object);
      Result := Object.Write (Buffer);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Destination (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return (Error => At_Destination
                   (Errors.Make (Errors.Destination_Write_Failed), Start),
                 Count => 0);
   end Write_Some;

   function Flush (Object : in out Streams.Destination'Class)
      return Errors.Error
   is
      Start : constant Streams.Destination_Position_Result := Position (Object);
      Result : Errors.Error;
   begin
      Result := Object.Flush;
      return (if Errors.Is_Fatal (Result)
              then At_Destination (Result, Start) else Result);
   exception
      when others =>
         return At_Destination
           (Errors.Make (Errors.Destination_Write_Failed), Start);
   end Flush;
end Giflib.Internal.Stream_Dispatch;
