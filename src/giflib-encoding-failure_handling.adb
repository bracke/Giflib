with Giflib.Encoding.Failure_Sequence;
with Giflib.Internal.Diagnostics;

package body Giflib.Encoding.Failure_Handling is
   use type Errors.Position_State;

   function Invalid_State (Object : Encoder) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Internal.Diagnostics.At_Destination (Object.Output.all))));

   function Fail
     (Object : in out Encoder; Item : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Destination_Position.State =
        Errors.Position_Not_Checked
      then
         Enriched.Context := Internal.Diagnostics.At_Destination
           (Object.Output.all, Enriched.Context);
      end if;
      return Failure_Sequence.Fail (Object, Enriched);
   end Fail;

   function Reject
     (Object : Encoder; Item : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Destination_Position.State =
        Errors.Position_Not_Checked
      then
         Enriched.Context := Internal.Diagnostics.At_Destination
           (Object.Output.all, Enriched.Context);
      end if;
      return Results.Failure (Enriched);
   end Reject;

   function Reject_Frame
     (Object : Encoder; Item : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if not Enriched.Context.Frame.Present then
         Enriched.Context.Frame := Errors.Frame_At (Object.Frames_Written);
      end if;
      return Reject (Object, Enriched);
   end Reject_Frame;

   function Fail_Frame_Request
     (Object : in out Encoder; Item : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if not Enriched.Context.Frame.Present then
         Enriched.Context.Frame := Errors.Frame_At (Object.Frames_Written);
      end if;
      return Fail (Object, Enriched);
   end Fail_Frame_Request;
end Giflib.Encoding.Failure_Handling;
