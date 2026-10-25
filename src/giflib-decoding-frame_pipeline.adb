with Giflib.Decoding.Resource_Management;
with Giflib.Decoding.Session_Transitions;
with Giflib.Decoding.State_Arithmetic;
with Giflib.Internal.Decoder_Storage;
with Giflib.Internal.Decoder_Storage.Image_Operations;
with Giflib.Internal.Diagnostics;

package body Giflib.Decoding.Frame_Pipeline is
   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result
   is
      Expected_Length : Byte_Count;
      Outcome : Results.Result;
   begin
      if not State_Arithmetic.Can_Process_Frame (Object.Current_State) then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode /= Required_Mode then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   others => <>))));
      elsif not Object.Has_Pending_Frame then
         return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      case Required_Mode is
         when Raw_Indexed =>
            Expected_Length := Internal.Geometry_Arithmetic.Area
              (Object.Pending_Frame.Width, Object.Pending_Frame.Height);
         when Expanded_Frame =>
            Expected_Length := Internal.Geometry_Arithmetic.Area
              (Object.Pending_Frame.Width, Object.Pending_Frame.Height) * 4;
         when Composited_RGBA =>
            if not Internal.Decoder_Storage.Canvas_Allocated (Object.Resources)
            then
               return Fail
                 (Object, Errors.Make (Errors.Internal_Invariant_Failed));
            end if;
            Expected_Length :=
              Internal.Decoder_Storage.Canvas_Length (Object.Resources);
      end case;
      Outcome := Validate_Frame_Output
        (Object, Target_Length, Expected_Length,
         Info_Is_Constrained,
         (if Info_Is_Constrained
          then Info_Has_Local_Palette
          else Object.Pending_Frame.Has_Local_Palette));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Session_Transitions.Begin_Frame (Object);
      Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Fail (Object, Outcome.First_Error));
   end Start_Decode;

   function Start_Skip (Object : in out Decoder) return Results.Result is
   begin
      if not State_Arithmetic.Can_Process_Frame (Object.Current_State) then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode = Composited_RGBA then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               Internal.Diagnostics.At_Source
                 (Object.Input.all,
                  (Frame => Errors.Frame_At (Object.Frames_Seen),
                   others => <>))));
      elsif not Object.Has_Pending_Frame then
         return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Session_Transitions.Begin_Frame (Object);
      return Results.Success;
   end Start_Skip;

   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result
   is
      Prepared : constant Prepared_Frame := Object.Pending_Frame;
      Decoded_Pixels : Pixel_Count := Object.Total_Decoded_Pixels;
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Internal.Decoder_Storage.Image_Operations.Decode_Indices
        (Object.Resources, Object.Input.all,
         Prepared.Width, Prepared.Height, Prepared.Interlaced,
         Prepared.Palette, Object.Constraints,
         Decoded_Pixels, Compressed_Bytes, Output, Object.Frames_Seen);
      Session_Transitions.Commit_Resource_Usage
        (Object, Decoded_Pixels, Compressed_Bytes);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Fail (Object, Outcome.First_Error));
   end Decode_Indices;

   function Decode_Scratch
     (Object : in out Decoder;
      Pixel_Bytes : Byte_Count) return Results.Result
   is
      Prepared : constant Prepared_Frame := Object.Pending_Frame;
      Decoded_Pixels : Pixel_Count := Object.Total_Decoded_Pixels;
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Internal.Decoder_Storage.Image_Operations.Decode_Frame_Scratch
        (Object.Resources, Object.Input.all,
         Prepared.Width, Prepared.Height, Prepared.Interlaced,
         Prepared.Palette, Object.Constraints,
         Decoded_Pixels, Compressed_Bytes, Pixel_Bytes, Object.Frames_Seen);
      Session_Transitions.Commit_Resource_Usage
        (Object, Decoded_Pixels, Compressed_Bytes);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Fail (Object, Outcome.First_Error));
   end Decode_Scratch;
end Giflib.Decoding.Frame_Pipeline;
