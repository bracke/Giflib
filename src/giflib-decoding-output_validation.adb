with Giflib.Decoding.Failure_Handling;
with Giflib.Internal.Diagnostics;

package body Giflib.Decoding.Output_Validation is
   function Validate
     (Object : Decoder;
      Target_Length : Byte_Count;
      Expected_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result
   is
   begin
      if Info_Is_Constrained
        and then Info_Has_Local_Palette /= Object.Pending_Frame.Has_Local_Palette
      then
         return Results.Failure
           (Failure_Handling.Variant_Error
              (Object, Boolean'Pos (Info_Has_Local_Palette),
               Boolean'Pos (Object.Pending_Frame.Has_Local_Palette)));
      elsif Target_Length /= Expected_Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   Expected => Expected_Length,
                   Actual => Target_Length,
                   others => <>))));
      end if;
      return Results.Success;
   end Validate;

   function Deliver
     (Object : in out Decoder;
      Event : out Decode_Event;
      Value : Decode_Event) return Results.Result
   is
   begin
      if Event'Constrained and then Event.Kind /= Value.Kind then
         return Failure_Handling.Fail
           (Object,
            Failure_Handling.Variant_Error
              (Object, Event_Kind'Pos (Event.Kind), Event_Kind'Pos (Value.Kind)));
      end if;
      Event := Value;
      return Results.Success;
   end Deliver;
end Giflib.Decoding.Output_Validation;
