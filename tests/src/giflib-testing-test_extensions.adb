with AUnit.Assertions;

with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Metadata_Arithmetic;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Extensions is
   use AUnit.Assertions;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frames.Graphic_Control;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Metadata.Extension_Kind;
   use type Giflib.Streams.Byte_Array;

   procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retained_Indexes_Grow_Boundedly
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Recognizes_Animexts_Loop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Covers_Retention_Policies_And_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Control_Field_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Metadata_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("extensions");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, GCE_Scopes_To_Next_Image'Access, "extensions.gce.image_scope");
      Register_Routine (T, Plain_Text_Consumes_GCE'Access, "extensions.gce.plain_text_scope");
      Register_Routine (T, Retains_Ordered_Metadata_And_Loop'Access,
                        "extensions.retention_order_and_loop");
      Register_Routine (T, Retained_Indexes_Grow_Boundedly'Access,
                        "extensions.retained_index_growth");
      Register_Routine (T, Recognizes_Animexts_Loop'Access,
                        "extensions.animexts_loop");
      Register_Routine (T, Covers_Retention_Policies_And_Bounds'Access,
                        "extensions.retention_policies_and_bounds");
      Register_Routine (T, Extension_Malformed_And_Budgets_Fail'Access,
                        "extensions.malformed_and_budgets");
      Register_Routine (T, Control_Field_Arithmetic_Is_Exact'Access,
                        "extensions.control_field_arithmetic");
      Register_Routine (T, Metadata_Arithmetic_Is_Exact'Access,
                        "extensions.metadata_arithmetic");
   end Register_Tests;

   procedure Metadata_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;
   begin
      Assert
        (Arithmetic.Classify (16#F9#) = Giflib.Metadata.Graphic_Control_Extension
         and then Arithmetic.Classify (16#FE#) = Giflib.Metadata.Comment_Extension
         and then Arithmetic.Classify (16#01#) = Giflib.Metadata.Plain_Text_Extension
         and then Arithmetic.Classify (16#FF#) = Giflib.Metadata.Application_Extension
         and then Arithmetic.Classify (16#02#) = Giflib.Metadata.Unknown_Extension,
         "extension label classification is wrong");
      Assert
        (Arithmetic.Block_For (Giflib.Metadata.Comment_Extension)
           = Giflib.Comment_Extension_Block
         and then Arithmetic.Should_Retain
           (Giflib.Metadata.Retain_Selected, Giflib.Metadata.Comment_Extension)
         and then not Arithmetic.Should_Retain
           (Giflib.Metadata.Retain_Selected, Giflib.Metadata.Plain_Text_Extension),
         "metadata retention classification is wrong");
      Assert
        (Arithmetic.Can_Append (Giflib.Byte_Count'Last - 1,
                                Giflib.Byte_Count'Last, 1)
         and then Arithmetic.Appended_Length
           (Giflib.Byte_Count'Last - 1, Giflib.Byte_Count'Last, 1)
             = Giflib.Byte_Count'Last
         and then Arithmetic.Increment (Natural'Last - 1) = Natural'Last,
         "metadata count accounting is wrong");
   end Metadata_Arithmetic_Is_Exact;

   procedure Control_Field_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Extension_Arithmetic;
      Control : constant Giflib.Frames.Graphic_Control :=
        (Disposal => 3,
         User_Input => True,
         Delay_CS => 65_535,
         Has_Transparency => True,
         Transparent_Index => 255);
      Packed : constant Giflib.Byte := Arithmetic.Encode_Graphic_Control (Control);
      Decoded : constant Giflib.Frames.Graphic_Control :=
        Arithmetic.Decode_Graphic_Control
          (Packed,
           Arithmetic.Low_Byte (Natural (Control.Delay_CS)),
           Arithmetic.High_Byte (Natural (Control.Delay_CS)),
           Giflib.Byte (Control.Transparent_Index));
   begin
      Assert (Packed = 15 and then Decoded = Control,
              "graphic-control packing round trip is wrong");
      Assert (Arithmetic.Decode_U16_LE (16#34#, 16#12#) = 16#1234#,
              "extension little-endian field decode is wrong");
      Assert (not Arithmetic.Has_Reserved_GCE_Bits (31)
              and then Arithmetic.Has_Reserved_GCE_Bits (32),
              "graphic-control reserved-bit classification is wrong");
   end Control_Field_Arithmetic_Is_Exact;

   function Header_With_Palette return Giflib.Streams.Byte_Array is
   begin
      return
        [71, 73, 70, 56, 57, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255];
   end Header_With_Palette;

   function Image_1x1 return Giflib.Streams.Byte_Array is
   begin
      return
        [16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 16#01#, 0];
   end Image_1x1;

   procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        Header_With_Palette &
        [16#21#, 16#F9#, 4, 11, 5, 0, 1, 0] &
        [16#21#, 16#FE#, 1, 65, 0] &
        Image_1x1 & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Kind = Giflib.Metadata.Graphic_Control_Extension,
              "GCE event failed");
      Assert (Event.Extension.Has_Graphic_Control
              and then Event.Extension.Graphic_Control.Disposal = 2
              and then Event.Extension.Graphic_Control.User_Input
              and then Event.Extension.Graphic_Control.Delay_CS = 5
              and then Event.Extension.Graphic_Control.Has_Transparency,
              "GCE event did not surface parsed control fields");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Kind = Giflib.Metadata.Comment_Extension,
              "comment between GCE and image failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome) and then Event.Kind = Giflib.Decoding.Image_Event,
              "image after GCE failed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "GCE-controlled image failed");
      Assert (Info.Control.Disposal = 2, "GCE disposal was not scoped to image");
      Assert (Info.Control.User_Input, "GCE user-input flag was not scoped to image");
      Assert (Info.Control.Delay_CS = 5, "GCE delay was not retained");
      Assert (Info.Control.Has_Transparency and then Info.Control.Transparent_Index = 1,
              "GCE transparency was not retained");
   end GCE_Scopes_To_Next_Image;

   procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        Header_With_Palette &
        [16#21#, 16#F9#, 4, 4, 0, 0, 0, 0] &
        [16#21#, 16#01#, 12, 0, 0, 0, 0, 1, 0, 1, 0, 8, 8, 1, 0, 1, 88, 0] &
        Image_1x1 & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "plain-text GCE failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Kind = Giflib.Metadata.Plain_Text_Extension,
              "plain-text event failed");
      Assert (Event.Extension.Has_Plain_Text_Header
              and then Event.Extension.Plain_Text.Grid_Width = 1
              and then Event.Extension.Plain_Text.Grid_Height = 1
              and then Event.Extension.Plain_Text.Cell_Width = 8
              and then Event.Extension.Plain_Text.Cell_Height = 8
              and then Event.Extension.Plain_Text.Foreground_Index = 1,
              "plain-text event did not surface parsed header fields");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "image event after plain text failed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "image after plain text failed");
      Assert (Info.Control = Giflib.Frames.Default_Control,
              "plain text did not consume pending GCE");
   end Plain_Text_Consumes_GCE;

   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Retained_Indexes_Grow_Boundedly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Recognizes_Animexts_Loop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#21#, 16#FF#, 11,
         65, 78, 73, 77, 69, 88, 84, 83, 49, 46, 48,
         3, 1, 5, 0, 0,
         16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Assert (Giflib.Results.Succeeded (Outcome),
              "ANIMEXTS fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome),
              "ANIMEXTS fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Kind = Giflib.Decoding.Extension_Event
              and then Event.Extension.Kind = Giflib.Metadata.Application_Extension
              and then Event.Extension.Has_Application_Identifier
              and then Event.Extension.Is_Loop_Extension
              and then Event.Extension.Loop_Count = 5
              and then Giflib.Decoding.Looping (Decoder).State
                = Giflib.Animations.Finite_Loop_Count
              and then Giflib.Decoding.Looping (Decoder).Raw_Count = 5,
              "ANIMEXTS finite loop was not recognized");
   end Recognizes_Animexts_Loop;

   procedure Covers_Retention_Policies_And_Bounds
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Extensions;
