with Giflib.Encoding.Extensions;
with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Request_Validation;
with Giflib.Encoding.Session_Transitions;
with Giflib.Encoding.State_Arithmetic;

package body Giflib.Encoding is
   use type Animations.Loop_State;
   use type Cleanup.Cleanup_Status;
   use type Errors.Error_Code;
   use type Metadata.Extension_Kind;

   function Write_Header (Object : in out Encoder) return Results.Result
   is separate;

   function Initialize
     (Object : in out Encoder;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits)
      return Results.Result
   is separate;

   function Define_Screen
     (Object : in out Encoder; Screen : Screen_Info) return Results.Result
   is
   begin
      if not State_Arithmetic.Can_Define_Screen
        (Object.Current_State)
      then
         return Failure_Handling.Invalid_State (Object);
      end if;
      declare
         Validation : constant Results.Result :=
           Request_Validation.Validate_Screen (Object, Screen);
      begin
         if not Results.Succeeded (Validation) then
            return Failure_Handling.Reject
              (Object, Validation.First_Error);
         end if;
      end;
      Session_Transitions.Define_Screen (Object, Screen);
      return Results.Success;
   end Define_Screen;

   function Set_Global_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result
   is
   begin
      if not State_Arithmetic.Can_Configure (Object.Current_State)
      then
         return Failure_Handling.Invalid_State (Object);
      end if;
      declare
         Validation : constant Results.Result :=
           Request_Validation.Validate_Global_Palette (Object, Palette);
      begin
         if not Results.Succeeded (Validation) then
            return Failure_Handling.Reject
              (Object, Validation.First_Error);
         end if;
      end;
      Session_Transitions.Set_Global_Palette (Object, Palette);
      return Results.Success;
   end Set_Global_Palette;

   function Set_Loop_Count
     (Object : in out Encoder;
      Count : Natural) return Results.Result
   is
   begin
      if not State_Arithmetic.Can_Configure (Object.Current_State)
      then
         return Failure_Handling.Invalid_State (Object);
      end if;
      declare
         Validation : constant Results.Result :=
           Request_Validation.Validate_Loop_Count (Object, Count);
      begin
         if not Results.Succeeded (Validation) then
            return Failure_Handling.Reject
              (Object, Validation.First_Error);
         end if;
      end;
      Session_Transitions.Set_Loop
        (Object,
         (if Count = 0
          then (State => Animations.Infinite_Looping)
          else (State => Animations.Finite_Loop_Count, Count => Count)));
      return Results.Success;
   end Set_Loop_Count;

   function Add_Indexed_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is separate;

   function Add_Extension
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result
   is
   begin
      return Extensions.Add (Object, Descriptor, Payload);
   end Add_Extension;

   function Add_Extension_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
   begin
      return Extensions.Add_Exact
        (Object, Descriptor, Payload, Chunk_Lengths);
   end Add_Extension_Exact;

   type Descriptor_Conversion (Supported : Boolean := False) is record
      case Supported is
         when True =>
            Descriptor : Extension_Descriptor;
         when False =>
            null;
      end case;
   end record;

   function Descriptor_For
     (Info : Metadata.Extension_Info) return Descriptor_Conversion
   is
   begin
      return
        (case Info.Kind is
            when Metadata.Comment_Extension =>
              (Supported => True,
               Descriptor => (Kind => Comment_Extension)),
            when Metadata.Plain_Text_Extension =>
              (Supported => True,
               Descriptor => (Kind => Plain_Text_Extension)),
            when Metadata.Application_Extension =>
              (Supported => True,
               Descriptor => (Kind => Application_Extension)),
            when Metadata.Unknown_Extension =>
              (Supported => True,
               Descriptor => (Kind => Unknown_Extension, Label => Info.Label)),
            when Metadata.Graphic_Control_Extension =>
              (Supported => False));
   end Descriptor_For;

   function Add_Decoded_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result
   is
      Conversion : constant Descriptor_Conversion := Descriptor_For (Info);
   begin
      if not Conversion.Supported then
         return Failure_Handling.Reject
           (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      return Add_Extension (Object, Conversion.Descriptor, Payload);
   end Add_Decoded_Extension;

   function Add_Decoded_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
      Conversion : constant Descriptor_Conversion := Descriptor_For (Info);
   begin
      if not Conversion.Supported then
         return Failure_Handling.Reject
           (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      return Add_Extension_Exact
        (Object, Conversion.Descriptor, Payload, Chunk_Lengths);
   end Add_Decoded_Extension_Exact;

   function Add_Truecolor_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Source : Images.Image_View;
      Options : Quantization.Quantize_Options := Quantization.Default_Options) return Results.Result
   is separate;

   function Finish (Object : in out Encoder) return Results.Result
   is separate;

   function Cancel (Object : in out Encoder) return Results.Result
   is separate;

   function State (Object : Encoder) return Encoder_State is
   begin
      return Object.Current_State;
   end State;

   function First_Error (Object : Encoder) return Errors.Error is
   begin
      return Object.Diagnostic;
   end First_Error;

   function First_Cleanup_Status
     (Object : Encoder) return Cleanup.Cleanup_Status is
      Quantizer_Status : constant Cleanup.Cleanup_Status :=
        Quantization.First_Cleanup_Status (Object.Quantizer_Data);
   begin
      return
        (if Quantizer_Status /= Cleanup.Cleanup_Complete
         then Quantizer_Status
         else Internal.Encoder_Storage.First_Cleanup_Status
           (Object.Resources));
   end First_Cleanup_Status;

   procedure Finalize (Object : in out Encoder)
   is separate;
end Giflib.Encoding;
