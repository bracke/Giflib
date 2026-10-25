separate (Giflib.Decoding)
function Next_Event
  (Object : in out Decoder;
   Event : out Decode_Event) return Results.Result
is
   Marker : Byte;
   Label_Value : Byte;
   Marker_Offset : Source_Offset;
   Extension_Info : Metadata.Extension_Info;
   Outcome : Results.Result;
   Position : Streams.Source_Position_Result;
   Pixels : Byte_Count;
begin
   if Object.Current_State = Completed then
      Position := Input_Position (Object);
      if not Position.Available then
         return Fail
           (Object, Errors.Make
              (Errors.Source_Read_Failed,
               (Source_Position => (State => Errors.Position_Unavailable),
                others => <>)));
      end if;
      return Deliver_Event
        (Object, Event, (Kind => End_Event, Offset => Position.Value));
   elsif not State_Arithmetic.Can_Read_Event (Object.Current_State) then
      return Invalid_Transition (Object);
   end if;
   Position := Input_Position (Object);
   if not Position.Available then
      return Fail
        (Object, Errors.Make
           (Errors.Source_Read_Failed,
            (Source_Position => (State => Errors.Position_Unavailable),
             others => <>)));
   end if;
   Marker_Offset := Position.Value;
   Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Marker);
   if not Results.Succeeded (Outcome) then
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         if Object.Options.Strictness = Recover_When_Safe
           and then Object.Frames_Seen > 0
         then
            Position := Input_Position (Object);
            if not Position.Available then
               return Fail
                 (Object, Errors.Make
                    (Errors.Source_Read_Failed,
                     (Source_Position =>
                        (State => Errors.Position_Unavailable),
                      others => <>)));
            end if;
            Add_Warning
              (Object, Errors.Recovery_Applied, Errors.Recovery,
               (Source_Position => Errors.Source_Position_At (Position.Value),
                Block => Trailer_Block, Expected => 1, Actual => 0,
                others => <>));
            State_Arithmetic.Complete_Stream (Object.Current_State);
            return Deliver_Event
              (Object, Event, (Kind => End_Event, Offset => Position.Value));
         end if;
         return Fail
           (Object, Errors.Make
              (Errors.Truncated_Block,
               Internal.Diagnostics.At_Source
                 (Object.Input.all, (Expected => 1, Actual => 0,
                                     others => <>))));
      end if;
      return Fail (Object, Outcome.First_Error);
   end if;
   case Marker is
      when Internal.Wire_Format.Image_Separator =>
         if Object.Frames_Seen >= Object.Constraints.Max_Frames then
            return Fail
              (Object, Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source_Position => Errors.Source_Position_At (Marker_Offset),
                   Block => Image_Descriptor_Block,
                   Frame => Errors.Frame_At (Object.Frames_Seen),
                   Expected => Byte_Count (Object.Constraints.Max_Frames),
                   Actual => Byte_Count (Object.Frames_Seen) + 1,
                   Limit => Frame_Count_Limit, others => <>)));
         end if;
         State_Arithmetic.Frame_Discovered (Object.Current_State);
         Outcome := Prepare_Frame (Object);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
         Pixels := Internal.Geometry_Arithmetic.Area
           (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
         State_Arithmetic.Await_Frame_Decision
           (Object.Current_State, Object.Has_Pending_Frame);
         return Deliver_Event
           (Object, Event,
            (Kind => Image_Event, Offset => Marker_Offset,
             Frame => Object.Frames_Seen,
             Left => Object.Pending_Frame.Left,
             Top => Object.Pending_Frame.Top,
             Width => Object.Pending_Frame.Width,
             Height => Object.Pending_Frame.Height,
             Interlaced => Object.Pending_Frame.Interlaced,
             Indexed_Bytes => Pixels, Expanded_Bytes => Pixels * 4));
      when Internal.Wire_Format.Trailer =>
         Outcome := Check_Trailing_Data (Object);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
         State_Arithmetic.Complete_Stream (Object.Current_State);
         return Deliver_Event
           (Object, Event, (Kind => End_Event, Offset => Marker_Offset));
      when Internal.Wire_Format.Extension_Introducer =>
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Label_Value);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
         Outcome := Read_Extension
           (Object, Marker_Offset, Label_Value, Extension_Info);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
         return Deliver_Event
           (Object, Event,
            (Kind => Extension_Event, Offset => Marker_Offset,
             Extension => Extension_Info));
      when others =>
         return Fail
           (Object, Errors.Make
              (Errors.Invalid_Block,
               (Source_Position => Errors.Source_Position_At (Marker_Offset),
                Expected => Byte_Count (Internal.Wire_Format.Image_Separator),
                Actual => Byte_Count (Marker), others => <>)));
   end case;
end Next_Event;
