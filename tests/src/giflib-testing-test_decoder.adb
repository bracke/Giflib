with AUnit.Assertions;
with Ada.Directories;

with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;
with Project_Tools.Files;

package body Giflib.Testing.Test_Decoder is
   use AUnit.Assertions;
   use type Giflib.Decoding.Decoder_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Decoding.Output_Mode;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Position_State;
   use type Giflib.Streams.Byte_Array;

   procedure Decodes_Independent_One_Pixel_GIF (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decodes_Local_Interlaced_GIF89a (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Failure_Preserves_First_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Independent_Decoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Expands_Frame_Rectangle_To_RGBA (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decodes_Independent_File_Corpus (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Unpositioned_Source (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Constrained_Header
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Constrained_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retries_Constrained_Frame_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retries_Incorrect_Indexed_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retries_Incorrect_RGBA_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   type Unpositioned_Source is limited new Giflib.Streams.Source with null record;
   overriding function Read
     (Object : in out Unpositioned_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Unpositioned_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Unpositioned_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   overriding function Read
     (Object : in out Unpositioned_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return (Count => 0, End_Of_Input => True, others => <>);
   end Read;

   overriding function Offset
     (Object : Unpositioned_Source) return Giflib.Source_Offset
   is
      pragma Unreferenced (Object);
   begin
      raise Program_Error;
      return 0;
   end Offset;

   overriding function Skip
     (Object : in out Unpositioned_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Count);
   begin
      return (Count => 0, End_Of_Input => True, others => <>);
   end Skip;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("decoder");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Decodes_Independent_One_Pixel_GIF'Access, "decoder.gif87a.one_pixel");
      Register_Routine (T, Decodes_Local_Interlaced_GIF89a'Access, "decoder.gif89a.local_interlaced");
      Register_Routine (T, Failure_Preserves_First_Diagnostic'Access, "decoder.failure_first_diagnostic");
      Register_Routine (T, State_Cancel_Reset_And_Unsupported'Access, "decoder.state_cancel_reset");
      Register_Routine (T, Skips_Indexed_Frame'Access, "decoder.skip_indexed_frame");
      Register_Routine (T, Independent_Decoders_Interleave'Access,
                        "decoder.independent_objects_interleave");
      Register_Routine (T, Expands_Frame_Rectangle_To_RGBA'Access,
                        "decoder.expanded_frame_rgba");
      Register_Routine (T, Decodes_Independent_File_Corpus'Access,
                        "decoder.independent_file_corpus");
      Register_Routine (T, Rejects_Unpositioned_Source'Access,
                        "decoder.requires_source_position");
      Register_Routine (T, Rejects_Constrained_Header'Access,
                        "decoder.constrained_header");
      Register_Routine (T, Rejects_Constrained_Event'Access,
                        "decoder.constrained_event");
      Register_Routine (T, Retries_Constrained_Frame_Info'Access,
                        "decoder.retry_frame_info_variant");
      Register_Routine (T, Retries_Incorrect_Indexed_Buffer'Access,
                        "decoder.retry_indexed_buffer_size");
      Register_Routine (T, Retries_Incorrect_RGBA_Buffer'Access,
                        "decoder.retry_rgba_buffer_size");
   end Register_Tests;

   procedure Rejects_Unpositioned_Source
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : aliased Unpositioned_Source;
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Source_Read_Failed
         and then Outcome.First_Error.Context.Source_Position.State =
           Giflib.Errors.Position_Unavailable,
         "decoder accepted a source without a reportable event offset");
   end Rejects_Unpositioned_Source;

   function One_Pixel_GIF return Giflib.Streams.Byte_Array is
   begin
      return
        [71, 73, 70, 56, 55, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 16#01#, 0,
         16#3B#];
   end One_Pixel_GIF;

   procedure Decodes_Independent_One_Pixel_GIF (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
      End_Offset : Giflib.Source_Offset;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "decoder initialization failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized, "wrong initialized state");

      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "public header read failed");
      Assert (Header.Version = Giflib.GIF87a and then Header.Width = 1 and then Header.Height = 1,
              "public header is wrong");

      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.Image_Event,
              "image event was not reported");
      Assert
        (Event.Left = 0 and then Event.Top = 0
         and then Event.Width = 1 and then Event.Height = 1
         and then not Event.Interlaced
         and then Event.Indexed_Bytes = 1
         and then Event.Expanded_Bytes = 4,
         "image event did not expose exact prepared-frame geometry");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "public indexed decode failed");
      Assert (Pixels = [0] and then Info.Ordinal = 0, "public indexed frame is wrong");

      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.End_Event,
              "end event was not reported");
      End_Offset := Source.Offset;
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Source.Offset = End_Offset,
              "repeated completion consumed source bytes");
      Giflib.Decoding.Finalize (Decoder);
      Giflib.Decoding.Finalize (Decoder);
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Finalized,
              "finalization is not idempotent");
   end Decodes_Independent_One_Pixel_GIF;

   procedure Rejects_Constrained_Header
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info (Has_Global_Palette => True);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch,
         "constrained header output raised or accepted the wrong variant");
   end Rejects_Constrained_Header;

   procedure Rejects_Constrained_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event
        (Kind => Giflib.Decoding.Image_Event);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch,
         "constrained event output raised or accepted the wrong variant");
   end Rejects_Constrained_Event;

   procedure Retries_Constrained_Frame_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event
        (Kind => Giflib.Decoding.Image_Event);
      Info : Giflib.Decoding.Frame_Info (Has_Local_Palette => True);
      Retry_Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Frame_Offset : Giflib.Source_Offset;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Frame_Offset := Source.Offset;
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch
         and then Giflib.Decoding.State (Decoder) =
           Giflib.Decoding.Awaiting_Frame_Decision
         and then Source.Offset = Frame_Offset,
         "constrained frame mismatch was not retryable");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame
        (Decoder, Pixel, Retry_Info);
      Assert
        (Giflib.Results.Succeeded (Outcome) and then Pixel = [0],
         "frame decode did not succeed after correcting its output variant");
   end Retries_Constrained_Frame_Info;

   procedure Retries_Incorrect_Indexed_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Wrong : Giflib.Streams.Byte_Array (1 .. 2);
      Correct : Giflib.Streams.Byte_Array (1 .. 1);
      Frame_Offset : Giflib.Source_Offset;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Frame_Offset := Source.Offset;
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Wrong, Info);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
         and then Giflib.Decoding.State (Decoder) =
           Giflib.Decoding.Awaiting_Frame_Decision
         and then Source.Offset = Frame_Offset,
         "raw buffer mismatch was not retryable");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Correct, Info);
      Assert
        (Giflib.Results.Succeeded (Outcome) and then Correct = [0],
         "raw decode did not succeed after correcting its buffer");
   end Retries_Incorrect_Indexed_Buffer;

   procedure Retries_Incorrect_RGBA_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Outcome : Giflib.Results.Result;
   begin
      for Mode in Giflib.Decoding.Expanded_Frame .. Giflib.Decoding.Composited_RGBA loop
         declare
            Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
            Decoder : Giflib.Decoding.Decoder (Source'Access);
            Options : Giflib.Decoding.Decode_Options :=
              Giflib.Decoding.Default_Options;
            Header : Giflib.Decoding.Header_Info;
            Event : Giflib.Decoding.Decode_Event;
            Info : Giflib.Decoding.Frame_Info;
            Wrong : Giflib.Streams.Byte_Array (1 .. 3);
            Correct : Giflib.Streams.Byte_Array (1 .. 4);
            Frame_Offset : Giflib.Source_Offset;
         begin
            Options.Mode := Mode;
            Giflib.Streams.Open (Source);
            Outcome := Giflib.Decoding.Initialize (Decoder, Options);
            Giflib.Testing.Assertions.Require_Success (Outcome);
            Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
            Giflib.Testing.Assertions.Require_Success (Outcome);
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Giflib.Testing.Assertions.Require_Success (Outcome);
            Frame_Offset := Source.Offset;
            if Mode = Giflib.Decoding.Expanded_Frame then
               Outcome := Giflib.Decoding.Decode_Expanded_Frame
                 (Decoder, Wrong, Info);
            else
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Wrong, Info);
            end if;
            Assert
              (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
               and then Giflib.Decoding.State (Decoder) =
                 Giflib.Decoding.Awaiting_Frame_Decision
               and then Source.Offset = Frame_Offset,
               "RGBA buffer mismatch was not retryable");
            if Mode = Giflib.Decoding.Expanded_Frame then
               Outcome := Giflib.Decoding.Decode_Expanded_Frame
                 (Decoder, Correct, Info);
            else
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Correct, Info);
            end if;
            Assert
              (Giflib.Results.Succeeded (Outcome),
               "RGBA decode did not succeed after correcting its buffer");
         end;
      end loop;
   end Retries_Incorrect_RGBA_Buffer;

   procedure Decodes_Local_Interlaced_GIF89a (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         2, 0, 4, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 2, 0, 4, 0, 16#C2#,
         0, 0, 0, 32, 0, 0, 64, 0, 0, 96, 0, 0,
         128, 0, 0, 160, 0, 0, 192, 0, 0, 224, 0, 0,
         3, 6, 8, 33, 67, 101, 39, 1, 0,
         16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 8);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF89a initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome) and then Header.Version = Giflib.GIF89a,
              "GIF89a header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF89a image event failed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "local interlaced GIF failed");
      Assert (Info.Interlaced and then Info.Has_Local_Palette, "frame flags were lost");
      Assert (Info.Effective_Palette.Length = 8, "local palette was not surfaced");
      Assert (Pixels = [0, 1, 4, 5, 2, 3, 6, 7], "interlaced public pixels are wrong");
   end Decodes_Local_Interlaced_GIF89a;

   procedure Failure_Preserves_First_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         1, 0, 1, 0, 16#80#, 0, 0, 0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#C4#, 16#0B#, 0, 16#3B#];
      Bad_Signature : aliased constant Giflib.Streams.Byte_Array :=
        [0, 73, 70, 56, 57, 97];
      Bad_Marker : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         1, 0, 1, 0, 0, 0, 0,
         0];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Bad_Source : aliased Giflib.Streams.Memory_Source (Bad_Signature'Access);
      Marker_Source : aliased Giflib.Streams.Memory_Source (Bad_Marker'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Bad_Decoder : Giflib.Decoding.Decoder (Bad_Source'Access);
      Marker_Decoder : Giflib.Decoding.Decoder (Marker_Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "malformed fixture image event failed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Outcome.First_Error.Code = Giflib.Errors.LZW_Invalid_Code,
              "malformed LZW has wrong public error");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Failed,
              "fatal data error did not fail decoder");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "invalid transition has wrong immediate error");
      Assert (Giflib.Decoding.First_Error (Decoder).Code = Giflib.Errors.LZW_Invalid_Code,
              "first fatal diagnostic was overwritten");

      Giflib.Streams.Open (Bad_Source);
      Outcome := Giflib.Decoding.Initialize (Bad_Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Bad_Decoder, Header);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Invalid_Signature
         and then Outcome.First_Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Outcome.First_Error.Context.Source_Position.Value = 0
         and then not Outcome.First_Error.Context.Frame.Present,
         "zero-offset signature diagnostic was overwritten by decoder context");

      Giflib.Streams.Open (Marker_Source);
      Outcome := Giflib.Decoding.Initialize (Marker_Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Marker_Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Marker_Decoder, Event);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Invalid_Block
         and then Outcome.First_Error.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Outcome.First_Error.Context.Source_Position.Value = 13,
         "invalid top-level marker was not rejected by the decoder");
   end Failure_Preserves_First_Diagnostic;

   procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Extension_Stream : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#21#, 16#FE#, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Other_Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Extension_Source : aliased Giflib.Streams.Memory_Source (Extension_Stream'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Other : Giflib.Decoding.Decoder (Other_Source'Access);
      Extension_Decoder : Giflib.Decoding.Decoder (Extension_Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "read-before-initialize was accepted");

      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture image event failed");
      Outcome := Giflib.Decoding.Cancel (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Cancelled,
              "cancellation state is wrong");

      Giflib.Streams.Open (Other_Source);
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Reset (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "reset failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized,
              "reset state is wrong");

      Options.Mode := Giflib.Decoding.Expanded_Frame;
      Outcome := Giflib.Decoding.Initialize (Other, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "expanded-frame mode initialization failed");
      Giflib.Decoding.Finalize (Other);

      Giflib.Streams.Open (Extension_Source);
      Outcome := Giflib.Decoding.Initialize
        (Extension_Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture reset failed");
      Outcome := Giflib.Decoding.Read_Header (Extension_Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Extension_Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "comment extension failed");
      Assert (Event.Kind = Giflib.Decoding.Extension_Event
              and then Giflib.Metadata.Label_Of (Event.Extension) = 16#FE#,
              "comment extension event lost its label");
   end State_Cancel_Reset_And_Unsupported;

   procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "skip fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "skip fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "skip fixture image event failed");
      Outcome := Giflib.Decoding.Skip_Frame (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "indexed frame skip failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.End_Event,
              "skip did not preserve next block boundary");
   end Skips_Indexed_Frame;

   procedure Independent_Decoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First_Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Second_Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 55, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#4C#, 16#01#, 0, 16#3B#];
      First_Source : aliased Giflib.Streams.Memory_Source (First_Fixture'Access);
      Second_Source : aliased Giflib.Streams.Memory_Source (Second_Fixture'Access);
      First_Decoder : Giflib.Decoding.Decoder (First_Source'Access);
      Second_Decoder : Giflib.Decoding.Decoder (Second_Source'Access);
      First_Header, Second_Header : Giflib.Decoding.Header_Info;
      First_Event, Second_Event : Giflib.Decoding.Decode_Event;
      First_Info, Second_Info : Giflib.Decoding.Frame_Info;
      First_Pixel, Second_Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (First_Source, Max_Transfer => 1);
      Giflib.Streams.Open (Second_Source, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (First_Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "first independent decoder failed to initialize");
      Outcome := Giflib.Decoding.Initialize (Second_Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "second independent decoder failed to initialize");
      Outcome := Giflib.Decoding.Read_Header (First_Decoder, First_Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Second_Decoder, Second_Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (First_Decoder, First_Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Second_Decoder, Second_Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Second_Decoder, Second_Pixel, Second_Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then Second_Pixel = [1],
              "second decoder state leaked or changed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (First_Decoder, First_Pixel, First_Info);
      Assert (Giflib.Results.Succeeded (Outcome) and then First_Pixel = [0],
              "first decoder state leaked or changed");
   end Independent_Decoders_Interleave;

   procedure Expands_Frame_Rectangle_To_RGBA (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         2, 0, 1, 0, 16#80#, 0, 0,
         255, 0, 0, 0, 255, 0,
         16#21#, 16#F9#, 4, 1, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0,
         2, 2, 16#44#, 16#0A#, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      RGBA : Giflib.Streams.Byte_Array (1 .. 8);
      Outcome : Giflib.Results.Result;
   begin
      Options.Mode := Giflib.Decoding.Expanded_Frame;
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Options);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Decode_Expanded_Frame (Decoder, RGBA, Info);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then RGBA = [255, 0, 0, 0, 0, 255, 0, 255],
              "expanded RGBA frame or transparent alpha is wrong");
   end Expands_Frame_Rectangle_To_RGBA;

   procedure Decodes_Independent_File_Corpus (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : constant String := Project_Tools.Files.Find_Root_Upward
        (Ada.Directories.Current_Directory, "giflib.gpr");
      Indexed_Expected : constant Giflib.Streams.Byte_Array :=
        [0, 0, 0, 255, 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
         0, 0, 0, 255,
         255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 255,
         255, 0, 0, 255,
         0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 255, 255, 0, 0, 255,
         0, 255, 0, 255];
      Animation_Expected : constant Giflib.Streams.Byte_Array :=
        [255, 0, 0, 255, 0, 255, 0, 255, 255, 0, 0, 255,
         0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255,
         0, 0, 255, 255, 0, 0, 255, 255, 255, 0, 0, 255];
      Interlaced_Expected : constant Giflib.Streams.Byte_Array :=
        [27, 22, 35, 255, 27, 22, 35, 255, 27, 22, 35, 255,
         114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
         183, 8, 105, 255, 183, 8, 105, 255, 183, 8, 105, 255,
         27, 22, 35, 255, 27, 22, 35, 255, 27, 22, 35, 255,
         114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
         183, 8, 105, 255, 213, 77, 184, 255, 213, 77, 184, 255,
         27, 22, 35, 255, 40, 77, 92, 255, 40, 77, 92, 255,
         114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
         213, 77, 184, 255, 213, 77, 184, 255, 213, 77, 184, 255,
         40, 77, 92, 255, 40, 77, 92, 255, 40, 77, 92, 255,
         111, 111, 161, 255, 111, 111, 161, 255, 111, 111, 161, 255,
         213, 77, 184, 255, 213, 77, 184, 255, 213, 77, 184, 255,
         47, 127, 142, 255, 47, 127, 142, 255, 47, 127, 142, 255,
         111, 111, 161, 255, 111, 111, 161, 255, 175, 159, 239, 255,
         175, 159, 239, 255, 175, 159, 239, 255, 175, 159, 239, 255,
         25, 172, 170, 255, 25, 172, 170, 255, 25, 172, 170, 255,
         111, 175, 219, 255, 111, 175, 219, 255, 175, 159, 239, 255,
         175, 159, 239, 255, 239, 175, 31, 255, 239, 175, 31, 255,
         25, 172, 170, 255, 25, 172, 170, 255, 79, 207, 231, 255,
         111, 175, 219, 255, 111, 175, 219, 255, 175, 223, 41, 255,
         175, 223, 41, 255, 239, 175, 31, 255, 239, 175, 31, 255,
         25, 236, 228, 255, 25, 236, 228, 255, 79, 207, 231, 255,
         79, 207, 231, 255, 103, 247, 24, 255, 175, 223, 41, 255,
         175, 223, 41, 255, 239, 239, 89, 255, 239, 239, 89, 255,
         25, 236, 228, 255, 25, 236, 228, 255, 103, 247, 24, 255,
         103, 247, 24, 255, 103, 247, 24, 255, 175, 223, 41, 255,
         175, 223, 41, 255, 239, 239, 89, 255, 239, 239, 89, 255];

      procedure Check_Composited
        (Relative_Path : String;
         Expected_Width : Giflib.Image_Width;
         Expected_Height : Giflib.Image_Height;
         Expected : Giflib.Streams.Byte_Array)
      is
         Raw : constant String := Project_Tools.Files.Read_Raw_File
           (Project_Tools.Files.Join (Root, Relative_Path));
         Data : aliased Giflib.Streams.Byte_Array := [for I in 1 .. Raw'Length => 0];
         Source : aliased Giflib.Streams.Memory_Source (Data'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Canvas : Giflib.Streams.Byte_Array
           (1 .. Natural (Expected_Width) * Natural (Expected_Height) * 4);
         Outcome : Giflib.Results.Result;
         Position : Natural := Expected'First;
      begin
         for I in Raw'Range loop
            Data (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
         end loop;
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source, Max_Transfer => 3);
         Outcome := Giflib.Decoding.Initialize (Decoder, Options);
         Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " initialization failed");
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Header.Width = Expected_Width
                 and then Header.Height = Expected_Height,
                 Relative_Path & " header changed");
         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " event decode failed");
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Assert (Position + Canvas'Length - 1 <= Expected'Last,
                       Relative_Path & " produced too many frames");
               Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
               Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " frame decode failed");
               Assert (Canvas = Expected (Position .. Position + Canvas'Length - 1),
                       Relative_Path & " composited pixels changed");
               Position := Position + Canvas'Length;
            end if;
         end loop;
         Assert (Position = Expected'Last + 1, Relative_Path & " produced too few frames");
         Giflib.Decoding.Finalize (Decoder);
      end Check_Composited;
   begin
      Assert (Root /= "", "could not locate repository root for independent fixtures");
      Check_Composited
        ("tests/fixtures/generated/imagemagick-indexed.gif", 5, 3, Indexed_Expected);
      Check_Composited
        ("tests/fixtures/generated/imagemagick-animation.gif", 3, 1, Animation_Expected);
      Check_Composited
        ("tests/fixtures/generated/imagemagick-interlaced.gif", 9, 9,
         Interlaced_Expected);
   end Decodes_Independent_File_Corpus;
end Giflib.Testing.Test_Decoder;
