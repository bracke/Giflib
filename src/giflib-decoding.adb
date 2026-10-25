with Giflib.Decoding.Extensions;
with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Decoder_Storage.Metadata_Operations;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Container;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Decoding.State_Arithmetic;
with Giflib.Internal.Stream_Arithmetic;
with Giflib.Internal.Wire_Format;

package body Giflib.Decoding is
   use type Errors.Error_Code;
   use type Errors.Position_State;
   use type Errors.Warning_Code;
   use type Frames.Disposal_Method;

   function Input_Position
     (Object : Decoder) return Streams.Source_Position_Result
   is
     (Streams.Position (Object.Input.all));
   function Invalid_Transition (Object : Decoder) return Results.Result is
   begin
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Internal.Diagnostics.At_Source (Object.Input.all)));
   end Invalid_Transition;

   function Fail (Object : in out Decoder; Item : Errors.Error) return Results.Result is
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
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Enriched;
      end if;
      Resource_Management.Release (Object);
      Session_Transitions.Fail_Session (Object);
      return Results.Failure (Object.Diagnostic);
   end Fail;

   function Output_Variant_Error
     (Object : Decoder;
      Expected : Natural;
      Actual : Natural) return Errors.Error
   is
   begin
      return Errors.Make
        (Errors.Output_Variant_Mismatch,
         Internal.Diagnostics.At_Source
           (Object.Input.all,
            (Expected => Byte_Count (Expected),
             Actual => Byte_Count (Actual),
             others => <>)));
   end Output_Variant_Error;

   function Validate_Frame_Output
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
           (Output_Variant_Error
              (Object,
               Boolean'Pos (Info_Has_Local_Palette),
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
   end Validate_Frame_Output;

   function Deliver_Event
     (Object : in out Decoder;
      Event : out Decode_Event;
      Value : Decode_Event) return Results.Result
   is
   begin
      if Event'Constrained and then Event.Kind /= Value.Kind then
         return Fail
           (Object,
            Output_Variant_Error
              (Object, Event_Kind'Pos (Event.Kind), Event_Kind'Pos (Value.Kind)));
      end if;
      Event := Value;
      return Results.Success;
   end Deliver_Event;

   procedure Add_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>))
   is
      Capacity : constant Limits.Warning_Record_Limit :=
        Object.Constraints.Max_Warning_Records;
      Enriched : Errors.Diagnostic_Context := Context;
   begin
      if Enriched.Source_Position.State = Errors.Position_Not_Checked then
         Enriched := Internal.Diagnostics.At_Source (Object.Input.all, Enriched);
      end if;
      if Capacity = 0 then
         return;
      elsif Object.Stored_Warnings < Capacity then
         Object.Stored_Warnings := Object.Stored_Warnings + 1;
         Object.Warnings (Object.Stored_Warnings) :=
           Errors.Make_Warning (Code, Severity, Enriched);
      elsif Object.Warnings (Capacity).Code /= Errors.Warnings_Suppressed then
         Object.Warnings (Capacity) :=
           Errors.Make_Warning
             (Errors.Warnings_Suppressed, Errors.Data_Loss, Enriched);
      end if;
   end Add_Warning;

   function Check_Trailing_Data (Object : in out Decoder) return Results.Result is
      Buffer : Streams.Byte_Array (1 .. 1);
      Step : Streams.Source_Result;
      Position : constant Streams.Source_Position_Result :=
        Input_Position (Object);
      Source_Context : constant Errors.Source_Position_Context :=
        (if Position.Available
         then Errors.Source_Position_At (Position.Value)
         else (State => Errors.Position_Unavailable));
   begin
      Step := Streams.Read_Some (Object.Input.all, Buffer);
      if Errors.Is_Fatal (Step.Error) then
         return Results.Failure (Step.Error);
      elsif not Internal.Stream_Arithmetic.Fits_Natural_Remaining
        (0, Buffer'Length, Step.Count)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source_Position => Source_Context,
                Expected => Byte_Count (Buffer'Length),
                Actual => Step.Count,
                others => <>)));
      elsif Step.Count = 0 and then Step.End_Of_Input then
         return Results.Success;
      elsif Step.Count = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Source_Zero_Progress,
               (Source_Position => Source_Context,
                others => <>)));
      elsif Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Trailing_Data,
               (Source_Position => Source_Context,
                Block => Trailing_Data_Block,
                Expected => 0,
                Actual => Step.Count,
                others => <>)));
      end if;
      Add_Warning
        (Object,
         Errors.Trailing_Data_Ignored,
         Errors.Compatibility,
         (Source_Position => Source_Context,
          Block => Trailing_Data_Block,
          Actual => Step.Count,
          others => <>));
      return Results.Success;
   end Check_Trailing_Data;

   function Read_Extension
     (Object : in out Decoder;
      Offset : Source_Offset;
      Label_Value : Byte;
      Info : out Metadata.Extension_Info) return Results.Result
   is
   begin
      return Extensions.Read (Object, Offset, Label_Value, Info);
   end Read_Extension;

   function Initialize
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      if not State_Arithmetic.Can_Initialize
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;
      Resource_Management.Release (Object);
      if not Internal.Decoder_Storage.Cleanup_Succeeded (Object.Resources) then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
         Session_Transitions.Fail_Session (Object);
         return Results.Failure (Object.Diagnostic);
      end if;
      if not Input_Position (Object).Available then
         Object.Diagnostic := Errors.Make
           (Errors.Source_Read_Failed,
            (Source_Position => (State => Errors.Position_Unavailable),
             others => <>));
         Session_Transitions.Fail_Session (Object);
         return Results.Failure (Object.Diagnostic);
      end if;
      Session_Transitions.Begin_Session (Object, Options, Constraints);
      return Results.Success;
   end Initialize;

   function Reset
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      Session_Transitions.Reset_Session (Object);
      return Initialize (Object, Options, Constraints);
   end Reset;

   function Read_Header
     (Object : in out Decoder;
      Header : out Header_Info) return Results.Result
   is
      Parsed : Internal.Container.Header_Info;
      Outcome : Results.Result;
   begin
      if not State_Arithmetic.Can_Read_Header
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;
      Outcome := Internal.Container.Read_Header (Object.Input.all, Object.Constraints, Parsed);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      if Header'Constrained
        and then Header.Has_Global_Palette /= Parsed.Has_Global_Palette
      then
         return Fail
           (Object,
            Output_Variant_Error
              (Object,
               Boolean'Pos (Header.Has_Global_Palette),
               Boolean'Pos (Parsed.Has_Global_Palette)));
      end if;
      Header := Parsed;
      if Object.Options.Mode = Composited_RGBA then
         Outcome := Resource_Management.Setup_Canvas (Object, Parsed);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Session_Transitions.Commit_Header (Object, Parsed);
      return Results.Success;
   end Read_Header;

   function Prepare_Frame
     (Object : in out Decoder) return Results.Result;

   function Next_Event
     (Object : in out Decoder;
      Event : out Decode_Event) return Results.Result
   is separate;

   function Prepare_Frame
     (Object : in out Decoder) return Results.Result
   is
      Prepared : Prepared_Frame renames Object.Pending_Frame;
      Descriptor : Internal.Container.Image_Descriptor;
      Outcome : Results.Result;
   begin
      Prepared := (others => <>);
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         Object.Header_Data,
         Object.Constraints,
         Descriptor,
         Prepared.Palette,
         Strictness => Object.Options.Strictness,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Prepared.Left := Descriptor.Left;
      Prepared.Top := Descriptor.Top;
      Prepared.Width := Descriptor.Width;
      Prepared.Height := Descriptor.Height;
      Prepared.Has_Local_Palette := Descriptor.Has_Local_Palette;
      Prepared.Interlaced := Descriptor.Interlaced;
      Prepared.Local_Palette_Sorted := Descriptor.Local_Palette_Sorted;
      if Descriptor.Reserved_Bits /= 0 then
         Add_Warning
           (Object,
            Errors.Reserved_Value_Accepted,
            Errors.Compatibility,
            (Source_Position => Descriptor.Packed_Field_Position,
             Block => Image_Descriptor_Block,
             Frame => Errors.Frame_At (Object.Frames_Seen),
             Expected => 0,
             Actual => Byte_Count (Descriptor.Reserved_Bits),
             others => <>));
      end if;
      Prepared.Control :=
        (if Object.Has_Pending_Control
         then Object.Pending_Control
         else Frames.Default_Control);
      if Prepared.Control.Has_Transparency
        and then not Palettes.Contains
          (Prepared.Palette, Prepared.Control.Transparent_Index)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               Internal.Diagnostics.At_Source
                  (Object.Input.all,
                   (Block => Graphic_Control_Extension_Block,
                    Frame => Errors.Frame_At (Object.Frames_Seen),
                    Expected => Byte_Count (Prepared.Palette.Length - 1),
                    Actual => Byte_Count (Prepared.Control.Transparent_Index),
                    others => <>))));
      end if;
      return Results.Success;
   end Prepare_Frame;

   function Complete_Frame
     (Object : in out Decoder;
      Info : out Frame_Info) return Results.Result
   is
      Prepared : Prepared_Frame renames Object.Pending_Frame;
      Produced : constant Frame_Info :=
        (if Prepared.Has_Local_Palette
         then
           (Has_Local_Palette => True,
            Ordinal => Object.Frames_Seen,
            Left => Prepared.Left,
            Top => Prepared.Top,
            Width => Prepared.Width,
            Height => Prepared.Height,
            Interlaced => Prepared.Interlaced,
            Effective_Palette => Prepared.Palette,
            Control => Prepared.Control,
            Local_Palette_Sorted => Prepared.Local_Palette_Sorted)
         else
           (Has_Local_Palette => False,
            Ordinal => Object.Frames_Seen,
            Left => Prepared.Left,
            Top => Prepared.Top,
            Width => Prepared.Width,
            Height => Prepared.Height,
            Interlaced => Prepared.Interlaced,
            Effective_Palette => Prepared.Palette,
            Control => Prepared.Control));
   begin
      Info := Produced;
      Session_Transitions.Complete_Frame (Object);
      return Results.Success;
   end Complete_Frame;

   function Decode_Indexed_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is separate;

   function Decode_Expanded_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is separate;
   function Decode_Composited_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is separate;

   function Skip_Frame (Object : in out Decoder) return Results.Result
   is separate;

   function Cancel (Object : in out Decoder) return Results.Result is
   begin
      if State_Arithmetic.Can_Cancel (Object.Current_State) then
         Resource_Management.Release (Object);
         if not Internal.Decoder_Storage.Cleanup_Succeeded (Object.Resources) then
            Session_Transitions.Fail_Session (Object);
            Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
            return Results.Failure (Object.Diagnostic);
         end if;
         Session_Transitions.Cancel_Session (Object);
         return Results.Success;
      elsif Object.Current_State = Cancelled then
         return Results.Success;
      elsif Object.Current_State = Failed then
         return Results.Failure (Object.Diagnostic);
      else
         return Invalid_Transition (Object);
      end if;
   end Cancel;

   function State (Object : Decoder) return Decoder_State is
   begin
      return Object.Current_State;
   end State;

   function First_Error (Object : Decoder) return Errors.Error is
   begin
      return Object.Diagnostic;
   end First_Error;

   function Warning_Count (Object : Decoder) return Natural is
   begin
      return Object.Stored_Warnings;
   end Warning_Count;

   function Warning_At
     (Object : Decoder;
      Index : Positive;
      Item : out Errors.Warning) return Results.Result
   is
   begin
      Item := Errors.Make_Warning (Errors.Generic_Warning, Errors.Informational);
      if Index > Object.Stored_Warnings then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Item := Object.Warnings (Index);
      return Results.Success;
   end Warning_At;

   function Looping (Object : Decoder) return Animations.Loop_Info is
   begin
      return Object.Loop_Data;
   end Looping;

   function Retained_Extension_Count (Object : Decoder) return Natural is
     (Internal.Decoder_Storage.Metadata_Operations.Count (Object.Resources));

   function Retained_Extension_Info
     (Object : Decoder;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result
   is
   begin
      return Internal.Decoder_Storage.Metadata_Operations.Info_At
        (Object.Resources, Index, Info);
   end Retained_Extension_Info;

   function Copy_Retained_Extension_Payload
     (Object : Decoder;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
   begin
      return Internal.Decoder_Storage.Metadata_Operations.Copy_Payload
        (Object.Resources, Index, Target, Count);
   end Copy_Retained_Extension_Payload;

   function Retained_Extension_Chunk_Count
     (Object : Decoder;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
   begin
      return Internal.Decoder_Storage.Metadata_Operations.Chunk_Count
        (Object.Resources, Index, Count);
   end Retained_Extension_Chunk_Count;

   function Copy_Retained_Extension_Chunk
     (Object : Decoder;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
   begin
      return Internal.Decoder_Storage.Metadata_Operations.Copy_Chunk
        (Object.Resources, Index, Chunk_Index, Target, Count);
   end Copy_Retained_Extension_Chunk;

   procedure Finalize (Object : in out Decoder) is
   begin
      Resource_Management.Release (Object);
      if not Internal.Decoder_Storage.Cleanup_Succeeded (Object.Resources)
        and then Object.Diagnostic.Code = Errors.No_Error
      then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
      end if;
      Session_Transitions.Finalize_Session (Object);
   end Finalize;
end Giflib.Decoding;
