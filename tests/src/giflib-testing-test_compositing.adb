with AUnit.Assertions;

with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Internal.Compositing;
with Giflib.Internal.Disposal;
with Giflib.Internal.Pixel_Arithmetic;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Compositing is
   use AUnit.Assertions;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Streams.Byte_Array;

   procedure Disposal_Zero_One_And_Transparency (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Disposal_Two_Restores_Background (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Disposal_Three_Restores_Previous (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Transparent_Initial_Canvas_And_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Pixel_Offsets_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rendering_Boundaries_Are_Checked (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("compositing");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Disposal_Zero_One_And_Transparency'Access,
                        "compositing.retain_and_transparency");
      Register_Routine (T, Disposal_Two_Restores_Background'Access,
                        "compositing.restore_background");
      Register_Routine (T, Disposal_Three_Restores_Previous'Access,
                        "compositing.restore_previous");
      Register_Routine (T, Transparent_Initial_Canvas_And_Budgets'Access,
                        "compositing.initial_policy_and_budgets");
      Register_Routine (T, Pixel_Offsets_Are_Bounded'Access,
                        "compositing.pixel_arithmetic");
      Register_Routine (T, Rendering_Boundaries_Are_Checked'Access,
                        "compositing.checked_boundaries");
   end Register_Tests;

   procedure Rendering_Boundaries_Are_Checked
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Canvas : Giflib.Streams.Byte_Array (1 .. 4) := [others => 0];
      Short : Giflib.Streams.Byte_Array (1 .. 3) := [others => 0];
      Oversized : Giflib.Streams.Byte_Array (1 .. 8) := [others => 0];
      Indices : constant Giflib.Streams.Byte_Array (1 .. 1) := [1 => 2];
      Palette : Giflib.Palettes.Palette;
      Rectangle : constant Giflib.Frames.Rectangle :=
        (Left => 0, Top => 0, Width => 1, Height => 1);
      Outcome : Giflib.Results.Result;
   begin
      Palette.Length := 2;
      Outcome := Giflib.Internal.Compositing.Overlay
        (Canvas, 1, Rectangle, Indices, Palette,
         Giflib.Frames.Default_Control);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
         "compositor accepted an out-of-palette index");

      Outcome := Giflib.Internal.Disposal.Fill_Rectangle
        (Short, 1, Rectangle, (others => 0), 0);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
         "disposal accepted a short canvas");

      Outcome := Giflib.Internal.Disposal.Capture_Rectangle
        (Canvas, 1, Rectangle, Short);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed,
         "snapshot capture accepted a short target");

      Outcome := Giflib.Internal.Disposal.Capture_Rectangle
        (Canvas, 1, Rectangle, Oversized);
      Assert
        (Giflib.Results.Succeeded (Outcome),
         "snapshot capture rejected reusable grow-only storage");
   end Rendering_Boundaries_Are_Checked;

   procedure Pixel_Offsets_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Pixel_Arithmetic;
   begin
      Assert (Arithmetic.Pixel_Index (2, 3, 10) = 32,
              "row-major pixel index is wrong");
      Assert (Arithmetic.Byte_Offset (2, 3, 10, 4) = 128,
              "RGBA byte offset is wrong");
      Assert (Arithmetic.Component_Offset (65_535, 4) = 262_140,
              "component offset is wrong");
   end Pixel_Offsets_Are_Bounded;

   function Header return Giflib.Streams.Byte_Array is
   begin
      return
        [71, 73, 70, 56, 57, 97,
         2, 0, 1, 0, 16#81#, 0, 0,
         0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255];
   end Header;

   function GCE
     (Disposal : Natural;
      Transparent : Boolean := False;
      Transparent_Index : Giflib.Byte := 0) return Giflib.Streams.Byte_Array
   is
      Packed : constant Giflib.Byte := Giflib.Byte (Disposal * 4 + (if Transparent then 1 else 0));
   begin
      return [16#21#, 16#F9#, 4, Packed, 0, 0, Transparent_Index, 0];
   end GCE;

   function One_Pixel (Left, Index : Natural) return Giflib.Streams.Byte_Array is
      Packed_Data : constant Giflib.Byte := Giflib.Byte (16#44# + Index * 8);
   begin
      return
        [16#2C#, Giflib.Byte (Left), 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, Packed_Data, 1, 0];
   end One_Pixel;

   function Two_Red_Pixels return Giflib.Streams.Byte_Array is
   begin
      return
        [16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0,
         2, 2, 16#4C#, 16#0A#, 0];
   end Two_Red_Pixels;

   procedure Begin_Decoder
     (Source : in out Giflib.Streams.Memory_Source;
      Decoder : in out Giflib.Decoding.Decoder;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : out Giflib.Results.Result)
   is
      Header_Info : Giflib.Decoding.Header_Info;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
   begin
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Giflib.Streams.Open (Source, Max_Transfer => 2);
      Outcome := Giflib.Decoding.Initialize (Decoder, Options, Constraints);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header_Info);
      end if;
   end Begin_Decoder;

   procedure Next_Canvas
     (Decoder : in out Giflib.Decoding.Decoder;
      Canvas : out Giflib.Streams.Byte_Array;
      Info : out Giflib.Decoding.Frame_Info;
      Outcome : out Giflib.Results.Result)
   is
      Event : Giflib.Decoding.Decode_Event;
   begin
      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         exit when not Giflib.Results.Succeeded (Outcome)
           or else Event.Kind = Giflib.Decoding.Image_Event;
      end loop;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
      end if;
   end Next_Canvas;

   procedure Disposal_Zero_One_And_Transparency (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        Header & GCE (0) & Two_Red_Pixels &
        GCE (1, True, 0) & One_Pixel (0, 0) &
        GCE (1) & One_Pixel (1, 3) & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Canvas : Giflib.Streams.Byte_Array (1 .. 8);
      Info : Giflib.Decoding.Frame_Info;
      Outcome : Giflib.Results.Result;
   begin
      Begin_Decoder (Source, Decoder, Outcome => Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "composited decoder setup failed");
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [255, 0, 0, 255, 255, 0, 0, 255], "first retained canvas is wrong");
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [255, 0, 0, 255, 255, 0, 0, 255],
              "transparent index painted over canvas");
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [255, 0, 0, 255, 0, 0, 255, 255],
              "disposal 0/1 did not retain canvas");
   end Disposal_Zero_One_And_Transparency;

   procedure Disposal_Two_Restores_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        Header & GCE (1) & Two_Red_Pixels &
        GCE (2) & One_Pixel (0, 2) &
        GCE (1) & One_Pixel (1, 3) & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Canvas : Giflib.Streams.Byte_Array (1 .. 8);
      Info : Giflib.Decoding.Frame_Info;
      Outcome : Giflib.Results.Result;
   begin
      Begin_Decoder (Source, Decoder, Outcome => Outcome);
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [0, 255, 0, 255, 255, 0, 0, 255], "disposal-2 frame draw is wrong");
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [0, 0, 0, 255, 0, 0, 255, 255],
              "disposal 2 did not restore logical background");
   end Disposal_Two_Restores_Background;

   procedure Disposal_Three_Restores_Previous (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Fixture : aliased constant Giflib.Streams.Byte_Array :=
        Header & GCE (1) & Two_Red_Pixels &
        GCE (3) & One_Pixel (0, 2) &
        GCE (1) & One_Pixel (1, 3) & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (Fixture'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Canvas : Giflib.Streams.Byte_Array (1 .. 8);
      Info : Giflib.Decoding.Frame_Info;
      Outcome : Giflib.Results.Result;
   begin
      Begin_Decoder (Source, Decoder, Outcome => Outcome);
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [0, 255, 0, 255, 255, 0, 0, 255], "disposal-3 frame draw is wrong");
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Canvas = [255, 0, 0, 255, 0, 0, 255, 255],
              "disposal 3 did not restore previous rectangle");
   end Disposal_Three_Restores_Previous;

   procedure Transparent_Initial_Canvas_And_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      No_Global : aliased constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 2, 0, 1, 0, 0, 0, 0,
         16#2C#, 1, 0, 0, 0, 1, 0, 1, 0, 16#80#,
         0, 0, 0, 255, 255, 255,
         2, 2, 16#4C#, 1, 0, 16#3B#];
      Snapshot_Limited : aliased constant Giflib.Streams.Byte_Array :=
        Header & GCE (3) & Two_Red_Pixels & [16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (No_Global'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Snapshot_Source : aliased Giflib.Streams.Memory_Source
        (Snapshot_Limited'Access);
      Snapshot_Decoder : Giflib.Decoding.Decoder (Snapshot_Source'Access);
      Canvas : Giflib.Streams.Byte_Array (1 .. 8);
      Info : Giflib.Decoding.Frame_Info;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Outcome : Giflib.Results.Result;
   begin
      Begin_Decoder (Source, Decoder, Outcome => Outcome);
      Next_Canvas (Decoder, Canvas, Info, Outcome);
      Assert (Giflib.Results.Succeeded (Outcome), "transparent initial canvas decode failed");
      Assert (Canvas = [0, 0, 0, 0, 255, 255, 255, 255],
              "missing background did not initialize transparent");

      Giflib.Decoding.Finalize (Decoder);
      Constraints.Max_Compositor_Snapshot_Bytes := 7;
      Begin_Decoder
        (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
      Next_Canvas (Snapshot_Decoder, Canvas, Info, Outcome);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
              "snapshot budget was ignored");
      Assert (Outcome.First_Error.Context.Limit = Giflib.Snapshot_Byte_Limit,
              "snapshot budget lost context");

      Giflib.Decoding.Finalize (Snapshot_Decoder);
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Canvas_Pixels := 1;
      Begin_Decoder
        (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Canvas_Pixel_Limit,
              "canvas pixel budget was ignored");

      Giflib.Decoding.Finalize (Snapshot_Decoder);
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Canvas_Bytes := 7;
      Begin_Decoder
        (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Canvas_Byte_Limit,
              "canvas byte budget was ignored");

      Giflib.Decoding.Finalize (Snapshot_Decoder);
      Constraints := Giflib.Limits.Default_Limits;
      Constraints.Max_Allocation_Bytes := 7;
      Begin_Decoder
        (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Allocation_Byte_Limit,
              "decoder allocation budget was ignored");
   end Transparent_Initial_Canvas_And_Budgets;
end Giflib.Testing.Test_Compositing;
