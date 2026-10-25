with AUnit.Assertions;

with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Encoding.Testing;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Images;
with Giflib.Internal.Encoding_Arithmetic;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Encoding is
   use AUnit.Assertions;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Encoding.Encoder_State;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Streams.Byte_Array;

   procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_GIF87a_Features_And_Bad_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Covers_Options_And_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Independent_Encoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Session_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Palette_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);
   function BW_Palette return Giflib.Palettes.Palette;
   procedure Destination_Exceptions_Are_Diagnostics
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   type Raising_Destination is limited new Giflib.Streams.Destination with null record;
   overriding function Write
     (Object : in out Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Raising_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Raising_Destination) return Giflib.Errors.Error;

   type Delayed_Raising_Destination is limited new Giflib.Streams.Destination with record
      Position : Giflib.Destination_Offset := 0;
      Write_Count : Natural := 0;
      Raise_On_Write : Natural := 0;
      Raise_On_Flush : Boolean := False;
   end record;
   overriding function Write
     (Object : in out Delayed_Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Delayed_Raising_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Delayed_Raising_Destination) return Giflib.Errors.Error;

   overriding function Write
     (Object : in out Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return (raise Storage_Error);
   end Write;

   overriding function Offset
     (Object : Raising_Destination) return Giflib.Destination_Offset
   is
      pragma Unreferenced (Object);
   begin
      return 0;
   end Offset;

   overriding function Flush
     (Object : in out Raising_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   overriding function Write
     (Object : in out Delayed_Raising_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result
   is
   begin
      Object.Write_Count := Object.Write_Count + 1;
      if Object.Raise_On_Write /= 0
        and then Object.Write_Count = Object.Raise_On_Write
      then
         raise Storage_Error;
      end if;
      Object.Position := Object.Position
        + Giflib.Destination_Offset (Buffer'Length);
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Buffer'Length));
   end Write;

   overriding function Offset
     (Object : Delayed_Raising_Destination) return Giflib.Destination_Offset
   is (Object.Position);

   overriding function Flush
     (Object : in out Delayed_Raising_Destination) return Giflib.Errors.Error
   is
   begin
      if Object.Raise_On_Flush then
         raise Storage_Error;
      end if;
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("encoding");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Encodes_Independent_GIF87a_Still'Access, "encoding.gif87a.still");
      Register_Routine (T, Encodes_GIF89a_Animation'Access, "encoding.gif89a.animation");
      Register_Routine (T, Rejects_GIF87a_Features_And_Bad_State'Access,
                        "encoding.invalid_feature_and_state");
      Register_Routine (T, Preserves_Extension_Payload_And_Placement'Access,
                        "encoding.extension_exact_placement");
      Register_Routine (T, Encodes_Truecolor_Local_And_Global'Access,
                        "encoding.truecolor.local_and_global");
      Register_Routine (T, Covers_Options_And_Lifecycle'Access,
                        "encoding.options_and_lifecycle");
      Register_Routine (T, Independent_Encoders_Interleave'Access,
                        "encoding.independent_objects_interleave");
      Register_Routine (T, Enforces_Session_Encoding_Budgets'Access,
                        "encoding.session_budgets");
      Register_Routine (T, Palette_Arithmetic_Is_Exact'Access,
                        "encoding.palette_arithmetic");
      Register_Routine (T, Destination_Exceptions_Are_Diagnostics'Access,
                        "encoding.destination_exception_diagnostic");
   end Register_Tests;

   procedure Destination_Exceptions_Are_Diagnostics
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Destination : aliased Raising_Destination;
      Delayed : aliased Delayed_Raising_Destination;
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      Delayed_Encoder : Giflib.Encoding.Encoder (Delayed'Access);
      Frame : constant Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 1, Height => 1, others => <>);
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24,
         Width => 1,
         Height => 1,
         Stride => 3,
         Accessible_Bytes => 3,
         Data => RGB'Access);
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Encoding.Initialize
        (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Encoder, (Width => 1, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder,
         Frame,
         Giflib.Encoding.Global_Frame_Palette,
         [1 => 0]);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
         "indexed destination Storage_Error was misclassified");

      Giflib.Encoding.Finalize (Encoder);
      Outcome := Giflib.Encoding.Initialize
        (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Encoder, (Width => 1, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Truecolor_Frame (Encoder, Frame, View);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed,
         "truecolor destination Storage_Error was misclassified");
      Giflib.Encoding.Finalize (Encoder);

      Delayed.Raise_On_Write := 7;
      Outcome := Giflib.Encoding.Initialize
        (Delayed_Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Delayed_Encoder, (Width => 1, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Delayed_Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Delayed_Encoder,
         Frame,
         Giflib.Encoding.Global_Frame_Palette,
         [1 => 0]);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed
         and then Giflib.Encoding.State (Delayed_Encoder) = Giflib.Encoding.Failed
         and then Giflib.Encoding.Testing.Bytes_Written (Delayed_Encoder) =
           Giflib.Byte_Count (Delayed.Position)
         and then Giflib.Encoding.Testing.Compressed_Bytes_Written
           (Delayed_Encoder) = 0,
         "LZW destination Storage_Error escaped the encoder");
      Giflib.Encoding.Finalize (Delayed_Encoder);

      Delayed.Position := 0;
      Delayed.Write_Count := 0;
      Delayed.Raise_On_Write := 0;
      Delayed.Raise_On_Flush := True;
      Outcome := Giflib.Encoding.Initialize
        (Delayed_Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen
        (Delayed_Encoder, (Width => 1, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Finish (Delayed_Encoder);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Destination_Write_Failed
         and then Giflib.Encoding.State (Delayed_Encoder) = Giflib.Encoding.Failed,
         "flush Storage_Error escaped the encoder");
      Giflib.Encoding.Finalize (Delayed_Encoder);
   end Destination_Exceptions_Are_Diagnostics;

   function BW_Palette return Giflib.Palettes.Palette is
      Item : Giflib.Palettes.Palette;
   begin
      Item.Length := 2;
      Item.Colors (0) := (0, 0, 0);
      Item.Colors (1) := (255, 255, 255);
      return Item;
   end BW_Palette;

   procedure Palette_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Encoding_Arithmetic;
   begin
      for Length in Arithmetic.Palette_Length loop
         declare
            Encoded : constant Arithmetic.Palette_Length :=
              Arithmetic.Encoded_Palette_Length (Length);
            Size : constant Arithmetic.Palette_Size_Code := Arithmetic.Size_Code (Encoded);
            Minimum : constant Natural := Natural (Arithmetic.Minimum_LZW_Code_Size (Encoded));
         begin
            Assert (Encoded >= Length and then Giflib.Palettes.Is_Encodable_Length (Encoded),
                    "palette length was not rounded to an encodable table");
            Assert (2 ** (Size + 1) = Encoded, "packed palette size code is wrong");
            Assert (2 ** Minimum >= Encoded, "minimum LZW code size is too small");
            Assert (Minimum = 2 or else 2 ** (Minimum - 1) < Encoded,
                    "minimum LZW code size is not minimal");
         end;
      end loop;
   end Palette_Arithmetic_Is_Exact;

   procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 256 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
      Frame : constant Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
      Outcome : Giflib.Results.Result;
      End_Offset : Giflib.Destination_Offset;
   begin
      Options.Version := Giflib.Encoding.Force_GIF87a;
      Giflib.Streams.Open (Destination, Max_Transfer => 2);
      Outcome := Giflib.Encoding.Initialize (Encoder, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a encoder initialization failed");
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a screen definition failed");
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a global palette failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [0, 1]);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a frame encode failed");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a finish failed");
      End_Offset := Destination.Offset;
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome) and then Destination.Offset = End_Offset,
              "repeated finish wrote a duplicate trailer");
      Assert (Storage (1 .. 6) = [71, 73, 70, 56, 55, 97], "GIF87a signature is wrong");

      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source, Max_Transfer => 1);
         Outcome := Giflib.Decoding.Initialize (Decoder);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Assert (Giflib.Results.Succeeded (Outcome) and then Header.Version = Giflib.GIF87a,
                 "independent decode rejected GIF87a output");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
                 "GIF87a output changed indexed pixels");
      end;
   end Encodes_Independent_GIF87a_Still;

   procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      First : Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
      Second : Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 2, Height => 1, Interlaced => True, others => <>);
      Local : Giflib.Palettes.Palette;
      Outcome : Giflib.Results.Result;
   begin
      First.Control := (Disposal => 1, Delay_CS => 3, others => <>);
      Second.Control :=
        (Disposal => 2, Delay_CS => 0, Has_Transparency => True,
         Transparent_Index => 0, others => <>);
      Local.Length := 2;
      Local.Colors (0) := (255, 0, 0);
      Local.Colors (1) := (0, 255, 0);
      Giflib.Streams.Open (Destination, Max_Transfer => 3);
      Outcome := Giflib.Encoding.Initialize (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
      Assert (Giflib.Results.Succeeded (Outcome), "loop definition failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, First, Giflib.Encoding.Global_Frame_Palette, [0, 1]);
      Assert (Giflib.Results.Succeeded (Outcome), "first animation frame failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Second,
         (Selection => Giflib.Encoding.Use_Local_Palette, Value => Local), [1, 0]);
      Assert (Giflib.Results.Succeeded (Outcome), "second animation frame failed");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "animation finish failed");
      Assert (Storage (1 .. 6) = [71, 73, 70, 56, 57, 97], "GIF89a signature is wrong");

      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source, Max_Transfer => 2);
         Outcome := Giflib.Decoding.Initialize (Decoder);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Event.Extension.Loop_Info.Is_Loop
                 and then Giflib.Decoding.Looping (Decoder).State = Giflib.Animations.Infinite_Looping,
                 "encoded infinite loop was not preserved");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
                 "first encoded animation frame changed");
         Assert (Info.Control.Disposal = 1, "first disposal changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [1, 0],
                 "second encoded animation frame changed");
         Assert (Info.Interlaced and then Info.Has_Local_Palette, "encoded frame flags changed");
         Assert (Info.Control.Disposal = 2 and then Info.Control.Has_Transparency,
                 "second frame control changed");
      end;
   end Encodes_GIF89a_Animation;

   procedure Rejects_GIF87a_Features_And_Bad_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 64 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "screen-before-initialize was accepted");
      Options.Version := Giflib.Encoding.Force_GIF87a;
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize (Encoder, Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Unsupported_Feature,
              "GIF87a loop extension was silently dropped");
      Assert (Destination.Offset = 0, "invalid GIF87a feature wrote partial output");
      Assert
        (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Screen_Defined
         and then Giflib.Encoding.First_Error (Encoder).Code =
           Giflib.Errors.No_Error,
         "rejected preflight request made the encoder terminal");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);

      Giflib.Encoding.Finalize (Encoder);
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Decoded_Extension
        (Encoder,
         (Kind => Giflib.Metadata.Graphic_Control_Extension,
          others => <>),
         [1 => 0]);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Unsupported_Feature
         and then Destination.Offset = 0
         and then Giflib.Encoding.State (Encoder) =
           Giflib.Encoding.Screen_Defined,
         "decoded graphic control bypassed frame-control encoding");
      Outcome := Giflib.Encoding.Add_Extension
        (Encoder,
         (Kind => Giflib.Encoding.Comment_Extension),
         [1 => 0]);
      Giflib.Testing.Assertions.Require_Success (Outcome);
   end Rejects_GIF87a_Features_And_Bad_State;

   procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
      Encoder : Giflib.Encoding.Encoder (Destination'Access);
      Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
      Extension : constant Giflib.Metadata.Extension_Info :=
        (Kind => Giflib.Metadata.Comment_Extension, others => <>);
      Large_Payload : constant Giflib.Streams.Byte_Array :=
        [for I in 1 .. 300 => Giflib.Byte ((I - 1) mod 256)];
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize (Encoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [0]);
      Assert (Giflib.Results.Succeeded (Outcome), "pre-extension frame failed");
      Outcome := Giflib.Encoding.Add_Decoded_Extension_Exact
        (Encoder, Extension, [65, 66, 67, 68, 69], [3, 2]);
      Assert (Giflib.Results.Succeeded (Outcome), "exact comment encode failed");
      Outcome := Giflib.Encoding.Add_Decoded_Extension
        (Encoder, Extension, Large_Payload);
      Assert (Giflib.Results.Succeeded (Outcome), "automatic comment chunking failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Global_Frame_Palette, [1]);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture finish failed");

      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source (Encoded'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Decode_Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
         Pixel : Giflib.Streams.Byte_Array (1 .. 1);
         Payload : Giflib.Streams.Byte_Array (1 .. 5);
         Large_Copy : Giflib.Streams.Byte_Array (1 .. Large_Payload'Length);
         Count : Giflib.Byte_Count;
         Chunk_Count : Natural;
      begin
         Decode_Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder, Decode_Options);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixel = [0],
                 "first placement frame changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Event.Extension.Before_Frame = 1,
                 "extension placement changed");
         Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count (Decoder, 1, Chunk_Count);
         Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
                 "extension chunk partition changed");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
           (Decoder, 1, Payload, Count);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Payload = [65, 66, 67, 68, 69],
                 "extension payload changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Event.Extension.Before_Frame = 1,
                 "automatically chunked extension placement changed");
         Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count
           (Decoder, 2, Chunk_Count);
         Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
                 "automatic extension chunk count is wrong");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
           (Decoder, 2, Large_Copy, Count);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Count = Giflib.Byte_Count (Large_Payload'Length)
                 and then Large_Copy = Large_Payload,
                 "automatically chunked extension payload changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Giflib.Testing.Assertions.Require_Success (Outcome);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixel = [1],
                 "second placement frame changed");
      end;
   end Preserves_Extension_Payload_And_Placement;

   procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Covers_Options_And_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Independent_Encoders_Interleave
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Enforces_Session_Encoding_Budgets
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Encoding;
