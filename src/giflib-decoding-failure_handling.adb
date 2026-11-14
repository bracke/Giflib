with Giflib.Decoding.Failure_Sequence;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Diagnostics;

package body Giflib.Decoding.Failure_Handling is
   use type Errors.Position_State;

   function Input_Position_Of
     (Object : Decoder) return Streams.Source_Position_Result
   is (Streams.Position (Object.Input.all));

   function Invalid_State (Object : Decoder) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Internal.Diagnostics.At_Source (Object.Input.all))));

   function Fail
     (Object : in out Decoder; Item : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Source_Position.State = Errors.Position_Not_Checked then
         Enriched.Context := Internal.Diagnostics.At_Source
           (Object.Input.all, Enriched.Context);
      end if;
      if not Enriched.Context.Frame.Present
        and then Object.Current_State in Awaiting_Frame_Decision | Decoding_Frame
      then
         Enriched.Context.Frame := Errors.Frame_At (Object.Frames_Seen);
      end if;
      return Failure_Sequence.Fail (Object, Enriched);
   end Fail;

   function Variant_Error
     (Object : Decoder; Expected : Natural; Actual : Natural)
      return Errors.Error
   is
     (Errors.Make
        (Errors.Output_Variant_Mismatch,
         Internal.Diagnostics.At_Source
           (Object.Input.all,
            (Expected => Byte_Count (Expected),
             Actual => Byte_Count (Actual),
             others => <>))));

   procedure Record_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>))
   is
      Enriched : Errors.Diagnostic_Context := Context;
   begin
      if Enriched.Source_Position.State = Errors.Position_Not_Checked then
         Enriched := Internal.Diagnostics.At_Source (Object.Input.all, Enriched);
      end if;
      Session_Transitions.Record_Warning
        (Object, Errors.Make_Warning (Code, Severity, Enriched));
   end Record_Warning;
end Giflib.Decoding.Failure_Handling;
