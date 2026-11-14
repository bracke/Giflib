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
   is separate;

   function BW_Palette return Giflib.Palettes.Palette is
      Item : Giflib.Palettes.Palette;
   begin
      Item.Length := 2;
      Item.Colors (0) := (0, 0, 0);
      Item.Colors (1) := (255, 255, 255);
      return Item;
   end BW_Palette;

   procedure Palette_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Encodes_Independent_GIF87a_Still (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Encodes_GIF89a_Animation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Rejects_GIF87a_Features_And_Bad_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Preserves_Extension_Payload_And_Placement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Encodes_Truecolor_Local_And_Global (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Covers_Options_And_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Independent_Encoders_Interleave
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Enforces_Session_Encoding_Budgets
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Encoding;
