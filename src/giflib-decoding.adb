with Giflib.Decoding.Extensions;
with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Frame_Compositing;
with Giflib.Decoding.Session_Transitions;
with Giflib.Internal.Decoder_Storage.Metadata_Operations;
with Giflib.Internal.Container;
with Giflib.Decoding.State_Arithmetic;

package body Giflib.Decoding is
   use type Errors.Error_Code;
   use type Errors.Position_State;
   use type Errors.Warning_Code;

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
      Constraints : Limits.Limit_Set := Limits.Default_Limits)
      return Results.Result
   is separate;

   function Reset
     (Object : in out Decoder;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is separate;

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
         return Failure_Handling.Invalid_State (Object);
      end if;
      Outcome := Internal.Container.Read_Header (Object.Input.all, Object.Constraints, Parsed);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail (Object, Outcome.First_Error);
      end if;
      if Header'Constrained
        and then Header.Has_Global_Palette /= Parsed.Has_Global_Palette
      then
         return Failure_Handling.Fail
           (Object,
            Failure_Handling.Variant_Error
              (Object,
               Boolean'Pos (Header.Has_Global_Palette),
               Boolean'Pos (Parsed.Has_Global_Palette)));
      end if;
      Header := Parsed;
      if Object.Options.Mode = Composited_RGBA then
         Outcome := Frame_Compositing.Setup_Canvas (Object, Parsed);
         if not Results.Succeeded (Outcome) then
            return Failure_Handling.Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Session_Transitions.Commit_Header (Object, Parsed);
      return Results.Success;
   end Read_Header;

   function Next_Event
     (Object : in out Decoder;
      Event : out Decode_Event) return Results.Result
   is separate;

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

   function Cancel (Object : in out Decoder) return Results.Result
   is separate;

   function State (Object : Decoder) return Decoder_State is
   begin
      return Object.Current_State;
   end State;

   function First_Error (Object : Decoder) return Errors.Error is
   begin
      return Object.Diagnostic;
   end First_Error;

   function First_Cleanup_Status
     (Object : Decoder) return Cleanup.Cleanup_Status is
   begin
      return Internal.Decoder_Storage.First_Cleanup_Status (Object.Resources);
   end First_Cleanup_Status;

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

   procedure Finalize (Object : in out Decoder)
   is separate;
end Giflib.Decoding;
