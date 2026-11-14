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
   is separate;

   procedure Pixel_Offsets_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Disposal_Zero_One_And_Transparency (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Disposal_Two_Restores_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Disposal_Three_Restores_Previous (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Transparent_Initial_Canvas_And_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Compositing;
