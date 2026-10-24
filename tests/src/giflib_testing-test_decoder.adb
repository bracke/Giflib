with AUnit.Assertions;

with Giflib;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Decoder is
   use AUnit.Assertions;
   use type Giflib.Byte;
   use type Giflib.Decoding.Decoder_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frame_Ordinal;
   use type Giflib.GIF_Version;
   use type Giflib.Image_Height;
   use type Giflib.Image_Width;
   use type Giflib.Source_Offset;
   use type Giflib.Streams.Byte_Array;

   procedure Decodes_Independent_One_Pixel_GIF (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decodes_Local_Interlaced_GIF89a (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Failure_Preserves_First_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Independent_Decoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Expands_Frame_Rectangle_To_RGBA (T : in out AUnit.Test_Cases.Test_Case'Class);

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
   end Register_Tests;

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
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
      End_Offset : Giflib.Source_Offset;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "decoder initialization failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized, "wrong initialized state");

      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "public header read failed");
      Assert (Header.Version = Giflib.GIF87a and then Header.Width = 1 and then Header.Height = 1,
              "public header is wrong");

      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.Image_Event,
              "image event was not reported");
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
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 8);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
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
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
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
   end Failure_Preserves_First_Diagnostic;

   procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Extension_Stream : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0, 16#21#, 16#FE#, 0, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source;
      Other_Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Other : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "read-before-initialize was accepted");

      Giflib.Streams.Open (Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation fixture image event failed");
      Outcome := Giflib.Decoding.Cancel (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "cancellation failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Cancelled,
              "cancellation state is wrong");

      Giflib.Streams.Open (Other_Source, Fixture'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset (Decoder, Other_Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "reset failed");
      Assert (Giflib.Decoding.State (Decoder) = Giflib.Decoding.Initialized,
              "reset state is wrong");

      Options.Mode := Giflib.Decoding.Expanded_Frame;
      Outcome := Giflib.Decoding.Initialize (Other, Other_Source'Unchecked_Access, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "expanded-frame mode initialization failed");
      Giflib.Decoding.Finalize (Other);

      Giflib.Streams.Open (Source, Extension_Stream'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset (Decoder, Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture reset failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "comment extension failed");
      Assert (Event.Kind = Giflib.Decoding.Extension_Event and then Event.Extension_Label = 16#FE#,
              "comment extension event lost its label");
   end State_Cancel_Reset_And_Unsupported;

   procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array := One_Pixel_GIF;
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
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
      First_Source, Second_Source : aliased Giflib.Streams.Memory_Source;
      First_Decoder, Second_Decoder : Giflib.Decoding.Decoder;
      First_Header, Second_Header : Giflib.Decoding.Header_Info;
      First_Event, Second_Event : Giflib.Decoding.Decode_Event;
      First_Info, Second_Info : Giflib.Decoding.Frame_Info;
      First_Pixel, Second_Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (First_Source, First_Fixture'Unchecked_Access, Max_Transfer => 1);
      Giflib.Streams.Open (Second_Source, Second_Fixture'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (First_Decoder, First_Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "first independent decoder failed to initialize");
      Outcome := Giflib.Decoding.Initialize (Second_Decoder, Second_Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "second independent decoder failed to initialize");
      Outcome := Giflib.Decoding.Read_Header (First_Decoder, First_Header);
      Outcome := Giflib.Decoding.Read_Header (Second_Decoder, Second_Header);
      Outcome := Giflib.Decoding.Next_Event (First_Decoder, First_Event);
      Outcome := Giflib.Decoding.Next_Event (Second_Decoder, Second_Event);
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
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      RGBA : Giflib.Streams.Byte_Array (1 .. 8);
      Outcome : Giflib.Results.Result;
   begin
      Options.Mode := Giflib.Decoding.Expanded_Frame;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Options);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Outcome := Giflib.Decoding.Decode_Expanded_Frame (Decoder, RGBA, Info);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then RGBA = [255, 0, 0, 0, 0, 255, 0, 255],
              "expanded RGBA frame or transparent alpha is wrong");
   end Expands_Frame_Rectangle_To_RGBA;
end Giflib_Testing.Test_Decoder;
