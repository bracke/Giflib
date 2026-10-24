with AUnit.Assertions;

with Giflib;
with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Images;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Encoding is
   use AUnit.Assertions;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Destination_Offset;
   use type Giflib.Encoding.Encoder_State;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frame_Ordinal;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.GIF_Version;
   use type Giflib.Limit_Kind;
   use type Giflib.Streams.Byte_Array;

   procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_GIF87a_Features_And_Bad_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Enforces_Session_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine (T, Enforces_Session_Encoding_Budgets'Access,
                        "encoding.session_budgets");
   end Register_Tests;

   function BW_Palette return Giflib.Palettes.Palette is
      Item : Giflib.Palettes.Palette;
   begin
      Item.Length := 2;
      Item.Colors (0) := (0, 0, 0);
      Item.Colors (1) := (255, 255, 255);
      return Item;
   end BW_Palette;

   procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 256 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
      Frame : constant Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
      Outcome : Giflib.Results.Result;
      End_Offset : Giflib.Destination_Offset;
   begin
      Options.Version := Giflib.Encoding.Force_GIF87a;
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access, Options);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a encoder initialization failed");
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a screen definition failed");
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Assert (Giflib.Results.Succeeded (Outcome), "GIF87a global palette failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0, 1]);
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
         Source : aliased Giflib.Streams.Memory_Source;
         Decoder : Giflib.Decoding.Decoder;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source, Encoded'Unchecked_Access, Max_Transfer => 1);
         Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Assert (Giflib.Results.Succeeded (Outcome) and then Header.Version = Giflib.GIF87a,
                 "independent decode rejected GIF87a output");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
                 "GIF87a output changed indexed pixels");
      end;
   end Encodes_Independent_GIF87a_Still;

   procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 1_024 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
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
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 3);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
      Assert (Giflib.Results.Succeeded (Outcome), "loop definition failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, First, Giflib.Encoding.Use_Global_Palette, (others => <>), [0, 1]);
      Assert (Giflib.Results.Succeeded (Outcome), "first animation frame failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Second, Giflib.Encoding.Use_Local_Palette, Local, [1, 0]);
      Assert (Giflib.Results.Succeeded (Outcome), "second animation frame failed");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "animation finish failed");
      Assert (Storage (1 .. 6) = [71, 73, 70, 56, 57, 97], "GIF89a signature is wrong");

      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source;
         Decoder : Giflib.Decoding.Decoder;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source, Encoded'Unchecked_Access, Max_Transfer => 2);
         Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Event.Extension.Is_Loop_Extension
                 and then Giflib.Decoding.Looping (Decoder).State = Giflib.Animations.Infinite_Looping,
                 "encoded infinite loop was not preserved");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixels = [0, 1],
                 "first encoded animation frame changed");
         Assert (Info.Control.Disposal = 1, "first disposal changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
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
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "screen-before-initialize was accepted");
      Options.Version := Giflib.Encoding.Force_GIF87a;
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access, Options);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Unsupported_Feature,
              "GIF87a loop extension was silently dropped");
      Assert (Destination.Offset = 0, "invalid GIF87a feature wrote partial output");
      Assert (Giflib.Encoding.State (Encoder) = Giflib.Encoding.Failed,
              "invalid feature did not fail encoder");
   end Rejects_GIF87a_Features_And_Bad_State;

   procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
      Extension : constant Giflib.Metadata.Extension_Info :=
        (Kind => Giflib.Metadata.Comment_Extension, Label => 16#FE#, others => <>);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
      Assert (Giflib.Results.Succeeded (Outcome), "pre-extension frame failed");
      Outcome := Giflib.Encoding.Add_Extension_Exact
        (Encoder, Extension, [65, 66, 67, 68, 69], [3, 2]);
      Assert (Giflib.Results.Succeeded (Outcome), "exact comment encode failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [1]);
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "extension fixture finish failed");

      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source;
         Decoder : Giflib.Decoding.Decoder;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Decode_Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
         Pixel : Giflib.Streams.Byte_Array (1 .. 1);
         Payload : Giflib.Streams.Byte_Array (1 .. 5);
         Count : Giflib.Byte_Count;
         Chunk_Count : Natural;
      begin
         Decode_Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
         Giflib.Streams.Open (Source, Encoded'Unchecked_Access);
         Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Decode_Options);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
         Assert (Pixel = [0], "first placement frame changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Event.Extension.Before_Frame = 1,
                 "extension placement changed");
         Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count (Decoder, 1, Chunk_Count);
         Assert (Chunk_Count = 2, "extension chunk partition changed");
         Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload
           (Decoder, 1, Payload, Count);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Payload = [65, 66, 67, 68, 69],
                 "extension payload changed");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
         Assert (Giflib.Results.Succeeded (Outcome) and then Pixel = [1],
                 "second placement frame changed");
      end;
   end Preserves_Extension_Payload_And_Placement;

   procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      RGBA : aliased constant Giflib.Streams.Byte_Array :=
        [255, 0, 0, 0, 0, 255, 0, 255];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGBA_32, Width => 2, Height => 1, Stride => 8,
         Accessible_Bytes => 8, Data => RGBA'Unchecked_Access);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Encoder, (Width => 2, Height => 1, others => <>), View);
      Assert (Giflib.Results.Succeeded (Outcome), "local truecolor frame failed");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Assert (Giflib.Results.Succeeded (Outcome), "local truecolor finish failed");
      declare
         Encoded : aliased constant Giflib.Streams.Byte_Array :=
           Storage (1 .. Natural (Destination.Offset));
         Source : aliased Giflib.Streams.Memory_Source;
         Decoder : Giflib.Decoding.Decoder;
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Pixels : Giflib.Streams.Byte_Array (1 .. 2);
      begin
         Giflib.Streams.Open (Source, Encoded'Unchecked_Access);
         Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Event.Kind = Giflib.Decoding.Extension_Event,
                 "truecolor alpha did not emit a control extension");
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Info.Has_Local_Palette
                 and then Info.Control.Has_Transparency
                 and then Pixels = [0, 1],
                 "local truecolor indices/transparency changed after encoding");
      end;

      declare
         RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0, 255, 255, 255];
         RGB_View : constant Giflib.Images.Image_View :=
           (Format => Giflib.RGB_24, Width => 2, Height => 1, Stride => 6,
            Accessible_Bytes => 6, Data => RGB'Unchecked_Access);
         Global_Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
         Global_Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
         Global_Encoder : Giflib.Encoding.Encoder;
         Encode_Options : Giflib.Encoding.Encode_Options := Giflib.Encoding.Default_Options;
      begin
         Encode_Options.Truecolor_Palettes := Giflib.Encoding.Use_Existing_Global;
         Giflib.Streams.Open (Global_Destination, Global_Storage'Unchecked_Access);
         Outcome := Giflib.Encoding.Initialize
           (Global_Encoder, Global_Destination'Unchecked_Access, Encode_Options);
         Outcome := Giflib.Encoding.Define_Screen
           (Global_Encoder, (Width => 2, Height => 1, others => <>));
         Outcome := Giflib.Encoding.Set_Global_Palette (Global_Encoder, BW_Palette);
         Outcome := Giflib.Encoding.Add_Truecolor_Frame
           (Global_Encoder, (Width => 2, Height => 1, others => <>), RGB_View);
         Assert (Giflib.Results.Succeeded (Outcome), "global truecolor frame failed");
         Outcome := Giflib.Encoding.Finish (Global_Encoder);
         Assert (Giflib.Results.Succeeded (Outcome), "global truecolor finish failed");
         declare
            Encoded : aliased constant Giflib.Streams.Byte_Array :=
              Global_Storage (1 .. Natural (Global_Destination.Offset));
            Source : aliased Giflib.Streams.Memory_Source;
            Decoder : Giflib.Decoding.Decoder;
            Header : Giflib.Decoding.Header_Info;
            Event : Giflib.Decoding.Decode_Event;
            Info : Giflib.Decoding.Frame_Info;
            Pixels : Giflib.Streams.Byte_Array (1 .. 2);
         begin
            Giflib.Streams.Open (Source, Encoded'Unchecked_Access);
            Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
            Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixels, Info);
            Assert (Giflib.Results.Succeeded (Outcome)
                    and then not Info.Has_Local_Palette and then Pixels = [0, 1],
                    "existing-global truecolor strategy was not retained");
         end;
      end;
   end Encodes_Truecolor_Local_And_Global;

   procedure Enforces_Session_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
      Outcome : Giflib.Results.Result;

      procedure Start is
      begin
         Giflib.Streams.Open (Destination, Storage'Unchecked_Access);
         Outcome := Giflib.Encoding.Initialize
           (Encoder, Destination'Unchecked_Access, Constraints => Constraints);
         Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
         if Giflib.Results.Succeeded (Outcome) then
            Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
         end if;
      end Start;
   begin
      Constraints.Max_Frames := 1;
      Start;
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [1]);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Frame_Count_Limit,
              "encoder frame-count budget was ignored");

      Giflib.Encoding.Finalize (Encoder);
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Output_Bytes := 10;
      Start;
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit,
              "encoder output-byte budget was ignored");

      Giflib.Encoding.Finalize (Encoder);
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Compressed_Bytes := 3;
      Start;
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
      Assert (Giflib.Results.Succeeded (Outcome), "first compressed-budget frame failed");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [1]);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Compressed_Byte_Limit,
              "cumulative compressed-byte budget was ignored");
   end Enforces_Session_Encoding_Budgets;
end Giflib_Testing.Test_Encoding;
