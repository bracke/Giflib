with AUnit.Assertions;

with Giflib;
with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Extensions is
   use AUnit.Assertions;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Byte;
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frames.Graphic_Control;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Delay_Centiseconds;
   use type Giflib.Limit_Kind;
   use type Giflib.Metadata.Extension_Kind;
   use type Giflib.Palette_Index;
   use type Giflib.Streams.Byte_Array;

   procedure GCE_Scopes_To_Next_Image (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Plain_Text_Consumes_GCE (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      Register_Routine (T, Extension_Malformed_And_Budgets_Fail'Access,
                        "extensions.malformed_and_budgets");
   end Register_Tests;

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
        [16#21#, 16#F9#, 4, 9, 5, 0, 1, 0] &
        [16#21#, 16#FE#, 1, 65, 0] &
        Image_1x1 & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixel : Giflib.Streams.Byte_Array (1 .. 1);
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 1);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome), "GCE fixture header failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Kind = Giflib.Metadata.Graphic_Control_Extension,
              "GCE event failed");
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
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "plain-text GCE failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Event.Extension.Kind = Giflib.Metadata.Plain_Text_Extension,
              "plain-text event failed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Giflib.Results.Succeeded (Outcome), "image event after plain text failed");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      Assert (Giflib.Results.Succeeded (Outcome), "image after plain text failed");
      Assert (Info.Control = Giflib.Frames.Default_Control,
              "plain text did not consume pending GCE");
   end Plain_Text_Consumes_GCE;

   procedure Retains_Ordered_Metadata_And_Loop (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#21#, 16#FE#, 3, 65, 66, 67, 2, 68, 69, 0,
         16#21#, 16#FF#, 11, 78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
         3, 1, 0, 0, 0,
         16#21#, 16#EE#, 1, 16#AA#, 0,
         16#3B#];
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Retained : Giflib.Metadata.Extension_Info;
      Payload : Giflib.Streams.Byte_Array (1 .. 20);
      Count : Giflib.Byte_Count;
      Chunk_Count : Natural;
      Outcome : Giflib.Results.Result;
      Labels : constant Giflib.Streams.Byte_Array := [16#FE#, 16#FF#, 16#EE#];
   begin
      Options.Retention := Giflib.Metadata.Retain_All_Exact_Bounded;
      Giflib.Streams.Open (Source, Fixture'Unchecked_Access, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Options);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      for Expected_Label of Labels loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome), "metadata event failed");
         Assert (Event.Extension_Label = Expected_Label, "metadata order changed");
      end loop;
      Assert (Giflib.Decoding.Retained_Extension_Count (Decoder) = 3,
              "retained extension count is wrong");
      Assert (Giflib.Decoding.Looping (Decoder).State = Giflib.Animations.Infinite_Looping,
              "infinite loop count was not recognized");

      Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 1, Retained);
      Assert (Giflib.Results.Succeeded (Outcome) and then Retained.Payload_Length = 5,
              "comment retention info is wrong");
      Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload (Decoder, 1, Payload, Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 5,
              "comment retention copy failed");
      Assert (Payload (1 .. 5) = [65, 66, 67, 68, 69], "comment payload changed");
      Outcome := Giflib.Decoding.Retained_Extension_Chunk_Count (Decoder, 1, Chunk_Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Chunk_Count = 2,
              "exact comment chunk count changed");
      Outcome := Giflib.Decoding.Copy_Retained_Extension_Chunk (Decoder, 1, 2, Payload, Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 2
              and then Payload (1 .. 2) = [68, 69],
              "exact comment chunk boundary changed");

      Outcome := Giflib.Decoding.Retained_Extension_Info (Decoder, 2, Retained);
      Assert (Retained.Is_Loop_Extension and then Retained.Loop_Count = 0,
              "loop metadata was not retained");
      Outcome := Giflib.Decoding.Copy_Retained_Extension_Payload (Decoder, 2, Payload, Count);
      Assert (Giflib.Results.Succeeded (Outcome) and then Count = 14,
              "application payload retention failed");
   end Retains_Ordered_Metadata_And_Loop;

   procedure Extension_Malformed_And_Budgets_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bad_GCE : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#21#, 16#F9#, 3, 0, 0, 0, 0];
      Large_Comment : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0,
         16#21#, 16#FE#, 3, 1, 2, 3, 2, 4, 5, 0];
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source, Bad_GCE'Unchecked_Access);
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Extension,
              "invalid GCE block size was accepted");

      Constraints.Max_Per_Extension_Bytes := 4;
      Giflib.Streams.Open (Source, Large_Comment'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset (Decoder, Source'Unchecked_Access,
                                        Constraints => Constraints);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "per-extension budget was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
              "extension budget lost context");

      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Extensions := 0;
      Giflib.Streams.Open (Source, Large_Comment'Unchecked_Access);
      Outcome := Giflib.Decoding.Reset
        (Decoder, Source'Unchecked_Access, Constraints => Constraints);
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Extension_Count_Limit,
              "extension count budget was ignored");

      declare
         Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      begin
         Options.Retention := Giflib.Metadata.Retain_All_Bounded;
         Constraints := Giflib.Limits.Default_Limits;
         Constraints.Max_Retained_Metadata_Bytes := 4;
         Giflib.Streams.Open (Source, Large_Comment'Unchecked_Access);
         Outcome := Giflib.Decoding.Reset
           (Decoder, Source'Unchecked_Access, Options, Constraints);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Outcome.First_Error.Context.Limit = Giflib.Retained_Metadata_Byte_Limit,
                 "retained metadata budget was ignored");
      end;
   end Extension_Malformed_And_Budgets_Fail;
end Giflib_Testing.Test_Extensions;
