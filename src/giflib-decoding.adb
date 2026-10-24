with Giflib.Decoding.Extensions;
with Giflib.Decoding.Resource_Management;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Container;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Compositing;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Image_Data;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Decoding.State_Arithmetic;
with Giflib.Internal.Session_Arithmetic;
with Giflib.Internal.Stream_Arithmetic;
with Giflib.Palettes;

package body Giflib.Decoding is
   use type Errors.Error_Code;
   use type Errors.Warning_Code;
   use type Frames.Disposal_Method;
   package Session_Arithmetic renames Internal.Session_Arithmetic;

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
      if not Enriched.Context.Has_Source then
         Enriched.Context := Internal.Diagnostics.At_Source
           (Object.Input.all, Enriched.Context);
      end if;
      if not Enriched.Context.Has_Frame
        and then Object.Current_State in Awaiting_Frame_Decision | Decoding_Frame
      then
         Enriched.Context.Has_Frame := True;
         Enriched.Context.Frame := Object.Frames_Seen;
      end if;
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Enriched;
      end if;
      Resource_Management.Release (Object);
      Object.Current_State := Failed;
      return Results.Failure (Object.Diagnostic);
   end Fail;

   procedure Add_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>))
   is
      Capacity : constant Natural := Session_Arithmetic.Warning_Capacity
        (Object.Constraints.Max_Warning_Records,
         Object.Constraints.Max_Diagnostic_Events);
      Enriched : Errors.Diagnostic_Context := Context;
   begin
      if not Enriched.Has_Source then
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
      Offset : constant Source_Offset := Position.Value;
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
               (Has_Source => Position.Available,
                Source => Offset,
                Expected => Byte_Count (Buffer'Length),
                Actual => Step.Count,
                others => <>)));
      elsif Step.Count = 0 and then Step.End_Of_Input then
         return Results.Success;
      elsif Step.Count = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Source_Zero_Progress,
               (Has_Source => Position.Available,
                Source => Offset,
                others => <>)));
      elsif Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Trailing_Data,
               (Has_Source => Position.Available, Source => Offset,
                Block => Trailing_Data_Block,
                Expected => 0,
                Actual => Step.Count,
                others => <>)));
      end if;
      Add_Warning
        (Object,
         Errors.Trailing_Data_Ignored,
         Errors.Compatibility,
         (Has_Source => Position.Available,
          Source => Offset,
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
      Object.Options := Options;
      Object.Constraints := Constraints;
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Resource_Management.Release (Object);
      if Object.Resources.Cleanup_Failed then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
         Object.Current_State := Failed;
         return Results.Failure (Object.Diagnostic);
      end if;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Stored_Warnings := 0;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      if not Input_Position (Object).Available then
         Object.Diagnostic := Errors.Make (Errors.Source_Read_Failed);
         Object.Current_State := Failed;
         return Results.Failure (Object.Diagnostic);
      end if;
      Object.Current_State := Initialized;
      return Results.Success;
   end Initialize;

   function Reset
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      Object.Current_State := Uninitialized;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      return Initialize (Object, Options, Constraints);
   end Reset;

   function Read_Header
     (Object : in out Decoder;
      Header : out Header_Info) return Results.Result
   is
      Parsed : Internal.Container.Header_Info;
      Outcome : Results.Result;
   begin
      Header := (others => <>);
      if not State_Arithmetic.Can_Read_Header
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;
      Outcome := Internal.Container.Read_Header (Object.Input.all, Object.Constraints, Parsed);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Header := Parsed;
      Object.Header_Data := Header;
      if Object.Options.Mode = Composited_RGBA then
         Outcome := Resource_Management.Setup_Canvas (Object);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Read_Header;

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
   begin
      Event := (others => <>);
      if Object.Current_State = Completed then
         Position := Input_Position (Object);
         if not Position.Available then
            return Fail (Object, Errors.Make (Errors.Source_Read_Failed));
         end if;
         Event := (Kind => End_Event, Offset => Position.Value, others => <>);
         return Results.Success;
      elsif not State_Arithmetic.Can_Read_Event
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;

      Position := Input_Position (Object);
      if not Position.Available then
         return Fail (Object, Errors.Make (Errors.Source_Read_Failed));
      end if;
      Marker_Offset := Position.Value;
      Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Marker);
      if not Results.Succeeded (Outcome) then
         if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
            if Object.Options.Strictness = Recover_When_Safe and then Object.Frames_Seen > 0 then
               Position := Input_Position (Object);
               if not Position.Available then
                  return Fail (Object, Errors.Make (Errors.Source_Read_Failed));
               end if;
               Add_Warning
                 (Object,
                  Errors.Recovery_Applied,
                  Errors.Recovery,
                  (Has_Source => True, Source => Position.Value,
                   Block => Trailer_Block,
                   Expected => 1,
                   Actual => 0,
                   others => <>));
               Event := (Kind => End_Event, Offset => Position.Value, others => <>);
               Object.Current_State := Completed;
               return Results.Success;
            end if;
            return Fail
              (Object,
               Errors.Make
                 (Errors.Truncated_Block,
                  Internal.Diagnostics.At_Source
                     (Object.Input.all,
                      (Expected => 1,
                       Actual => 0,
                       others => <>))));
         end if;
         return Fail (Object, Outcome.First_Error);
      end if;

      case Marker is
         when 16#2C# =>
            if Object.Frames_Seen >= Object.Constraints.Max_Frames then
               return Fail
                 (Object,
                  Errors.Make
                    (Errors.Limit_Exceeded,
                     (Has_Source => True, Source => Marker_Offset,
                      Block => Image_Descriptor_Block,
                      Has_Frame => True,
                      Frame => Object.Frames_Seen,
                      Expected => Byte_Count (Object.Constraints.Max_Frames),
                      Actual => Byte_Count (Object.Frames_Seen) + 1,
                      Limit => Frame_Count_Limit,
                      others => <>)));
            end if;
            Event :=
              (Kind => Image_Event,
               Offset => Marker_Offset,
               Frame => Object.Frames_Seen,
               Extension_Label => 0,
               Extension => <>);
            Object.Current_State := Awaiting_Frame_Decision;
            return Results.Success;
         when 16#3B# =>
            Outcome := Check_Trailing_Data (Object);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Event := (Kind => End_Event, Offset => Marker_Offset, others => <>);
            Object.Current_State := Completed;
            return Results.Success;
         when 16#21# =>
            Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Label_Value);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Outcome := Read_Extension (Object, Marker_Offset, Label_Value, Extension_Info);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Event :=
              (Kind => Extension_Event,
               Offset => Marker_Offset,
               Frame => Object.Frames_Seen,
               Extension_Label => Label_Value,
               Extension => Extension_Info);
            return Results.Success;
         when others =>
            return Fail
              (Object,
               Errors.Make
                 (Errors.Invalid_Block,
                  (Has_Source => True, Source => Marker_Offset,
                   Expected => 16#2C#,
                   Actual => Byte_Count (Marker),
                   others => <>)));
      end case;
   end Next_Event;

   type Prepared_Frame is record
      Descriptor : Internal.Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control := Frames.Default_Control;
   end record;

   function Prepare_Frame
     (Object : in out Decoder;
      Prepared : out Prepared_Frame) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Prepared := (others => <>);
      Object.Current_State := Decoding_Frame;
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         Object.Header_Data,
         Object.Constraints,
         Prepared.Descriptor,
         Prepared.Palette,
         Strictness => Object.Options.Strictness,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Prepared.Descriptor.Reserved_Bits /= 0 then
         Add_Warning
           (Object,
            Errors.Reserved_Value_Accepted,
            Errors.Compatibility,
            (Has_Source => Prepared.Descriptor.Has_Packed_Field_Offset,
             Source => Prepared.Descriptor.Packed_Field_Offset,
             Block => Image_Descriptor_Block,
             Has_Frame => True,
             Frame => Object.Frames_Seen,
             Expected => 0,
             Actual => Byte_Count (Prepared.Descriptor.Reserved_Bits),
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
                    Has_Frame => True,
                    Frame => Object.Frames_Seen,
                    Expected => Byte_Count (Prepared.Palette.Length - 1),
                    Actual => Byte_Count (Prepared.Control.Transparent_Index),
                    others => <>))));
      end if;
      return Results.Success;
   end Prepare_Frame;

   procedure Complete_Frame
     (Object : in out Decoder;
      Prepared : Prepared_Frame;
      Info : out Frame_Info)
   is
   begin
      Info :=
        (Ordinal => Object.Frames_Seen,
         Left => Prepared.Descriptor.Left,
         Top => Prepared.Descriptor.Top,
         Width => Prepared.Descriptor.Width,
         Height => Prepared.Descriptor.Height,
         Interlaced => Prepared.Descriptor.Interlaced,
         Has_Local_Palette => Prepared.Descriptor.Has_Local_Palette,
         Local_Palette_Sorted => Prepared.Descriptor.Local_Palette_Sorted,
         Effective_Palette => Prepared.Palette,
         Control => Prepared.Control);
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
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
         if Object.Resources.Cleanup_Failed then
            Object.Current_State := Failed;
            Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
            return Results.Failure (Object.Diagnostic);
         end if;
         Object.Current_State := Cancelled;
         Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
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
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Item := Object.Warnings (Index);
      return Results.Success;
   end Warning_At;

   function Looping (Object : Decoder) return Animations.Loop_Info is
   begin
      return Object.Loop_Data;
   end Looping;

   function Retained_Extension_Count (Object : Decoder) return Natural is
     (Internal.Metadata_Store.Count (Object.Resources.Metadata_Storage));

   function Retained_Extension_Info
     (Object : Decoder;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result
   is
   begin
      return Internal.Metadata_Store.Info_At
        (Object.Resources.Metadata_Storage, Index, Info);
   end Retained_Extension_Info;

   function Copy_Retained_Extension_Payload
     (Object : Decoder;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
   begin
      return Internal.Metadata_Store.Copy_Payload
        (Object.Resources.Metadata_Storage, Index, Target, Count);
   end Copy_Retained_Extension_Payload;

   function Retained_Extension_Chunk_Count
     (Object : Decoder;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
   begin
      return Internal.Metadata_Store.Chunk_Count
        (Object.Resources.Metadata_Storage, Index, Count);
   end Retained_Extension_Chunk_Count;

   function Copy_Retained_Extension_Chunk
     (Object : Decoder;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
   begin
      return Internal.Metadata_Store.Copy_Chunk
        (Object.Resources.Metadata_Storage, Index, Chunk_Index, Target, Count);
   end Copy_Retained_Extension_Chunk;

   overriding procedure Finalize (Object : in out Decoder_Resources) is
   begin
      Resource_Management.Release (Object);
   end Finalize;

   procedure Finalize (Object : in out Decoder) is
   begin
      Resource_Management.Release (Object);
      if Object.Resources.Cleanup_Failed
        and then Object.Diagnostic.Code = Errors.No_Error
      then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
      end if;
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Stored_Warnings := 0;
      Object.Current_State := Finalized;
   end Finalize;
end Giflib.Decoding;
