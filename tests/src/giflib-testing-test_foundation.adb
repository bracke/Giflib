with AUnit.Assertions;

with Giflib.Capabilities;
with Giflib.Decoding;
with Giflib.Decoding.Testing;
with Giflib.Encoding;
with Giflib.Encoding.Testing;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Session_Arithmetic;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Foundation is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Position_State;
   use type Giflib.Errors.Warning_Code;
   use type Giflib.Errors.Warning_Severity;
   use type Giflib.Results.Status;

   procedure Capabilities_Are_Advertised (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Helpers_And_Warnings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Session_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Controlled_Objects_Finalize_Automatically
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("foundation");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Capabilities_Are_Advertised'Access,
         "foundation.capabilities");
      Register_Routine (T, Results_Preserve_First_Error'Access, "foundation.results.status_and_error");
      Register_Routine (T, Error_Identifiers_And_Context'Access, "foundation.errors.context");
      Register_Routine (T, Defaults_Cover_Every_Limit'Access, "foundation.limits.defaults");
      Register_Routine (T, Helpers_And_Warnings'Access, "foundation.helpers_and_warnings");
      Register_Routine (T, Session_Arithmetic_Is_Bounded'Access,
                        "foundation.session_arithmetic");
      Register_Routine
        (T,
         Controlled_Objects_Finalize_Automatically'Access,
         "foundation.automatic_finalization");
   end Register_Tests;

   procedure Controlled_Objects_Finalize_Automatically
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      GIF_Data : aliased constant Giflib.Streams.Byte_Array :=
        [16#47#, 16#49#, 16#46#, 16#38#, 16#39#, 16#61#,
         1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255, 16#3B#];
      Source : aliased Giflib.Streams.Memory_Source (GIF_Data'Access);
      Destination_Data : aliased Giflib.Streams.Byte_Array :=
        [for I in 1 .. 1_024 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Destination_Data'Access);
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24,
         Width => 1,
         Height => 1,
         Stride => 3,
         Accessible_Bytes => 3,
         Data => RGB'Access);
      Indexed : Giflib.Streams.Byte_Array (1 .. 1);
      Quantized : Giflib.Quantization.Quantization_Result;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Source);
      declare
         Object : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Options : Giflib.Decoding.Decode_Options :=
           Giflib.Decoding.Default_Options;
      begin
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Outcome := Giflib.Decoding.Initialize
           (Object, Options);
         Assert (Giflib.Results.Succeeded (Outcome),
                 "automatic-finalization decoder initialization failed");
         Outcome := Giflib.Decoding.Read_Header (Object, Header);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Giflib.Decoding.Testing.Allocated_Bytes (Object) > 0,
            "automatic-finalization decoder did not own a canvas");
      end;

      Giflib.Streams.Open
        (Destination);
      declare
         Object : Giflib.Encoding.Encoder (Destination'Access);
      begin
         Outcome := Giflib.Encoding.Initialize
           (Object);
         Assert (Giflib.Results.Succeeded (Outcome),
                 "automatic-finalization encoder initialization failed");
         Outcome := Giflib.Encoding.Define_Screen (Object, (others => <>));
         Assert (Giflib.Results.Succeeded (Outcome),
                 "automatic-finalization encoder setup failed");
         Outcome := Giflib.Encoding.Add_Truecolor_Frame
           (Object, (others => <>), View);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Giflib.Encoding.Testing.Allocated_Bytes (Object) > 0,
            "automatic-finalization encoder did not own a workspace");
      end;

      declare
         Object : Giflib.Quantization.Workspace;
      begin
         Outcome := Giflib.Quantization.Quantize
           (Object, View, Indexed, Quantized);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Giflib.Quantization.Allocated_Bytes (Object) > 0,
            "automatic-finalization quantizer did not retain storage");
      end;
      --  Reaching this point verifies that all three controlled finalizers ran
      --  during scope exit without propagating an exception.
   end Controlled_Objects_Finalize_Automatically;

   procedure Session_Arithmetic_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Session_Arithmetic;
      Budget : constant Giflib.Internal.Budget_Arithmetic.Charge_Result :=
        Giflib.Internal.Budget_Arithmetic.Charge
          (Giflib.Byte_Count'Last - 1, Giflib.Byte_Count'Last, 1);
      Overflow : constant Giflib.Internal.Budget_Arithmetic.Charge_Result :=
        Giflib.Internal.Budget_Arithmetic.Charge
          (Giflib.Byte_Count'Last, Giflib.Byte_Count'Last, 1);
   begin
      Assert
        (Arithmetic.Warning_Capacity (Natural'Last) = 256
         and then Arithmetic.Has_Natural_Capacity
           (Natural'Last - 1, Natural'Last, 1),
         "session count capacity is wrong");
      Assert
        (Budget.Accepted
         and then Budget.Total = Giflib.Byte_Count'Last
         and then not Overflow.Accepted
         and then Overflow.Attempted = Giflib.Byte_Count'Last,
         "allocation accounting is wrong");
   end Session_Arithmetic_Is_Bounded;

   procedure Capabilities_Are_Advertised
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Giflib.Capabilities.Memory_Streams, "memory streams must be advertised");
      Assert (Giflib.Capabilities.Foundation_API, "foundation capability must be advertised");
      Assert (Giflib.Capabilities.Container_Decoding, "container decoder is not advertised");
      Assert (Giflib.Capabilities.Indexed_Decoding, "indexed decoder is not advertised");
      Assert (Giflib.Capabilities.Composited_Decoding,
              "composited decoder is not advertised");
      Assert (Giflib.Capabilities.Indexed_Encoding, "indexed encoder is not advertised");
      Assert (Giflib.Capabilities.Animation_Encoding, "animation encoder is not advertised");
      Assert (Giflib.Capabilities.Truecolor_Encoding, "truecolor encoder is not advertised");
      Assert (Giflib.Capabilities.Quantization, "quantization is not advertised");
      Assert (Giflib.Capabilities.Frame_Optimization, "optimization is not advertised");
      Assert (Giflib.Image_Width'First = 1, "image widths must be positive");
      Assert (Giflib.Coordinate'First = 0, "coordinates must be zero based");
   end Capabilities_Are_Advertised;

   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Good : constant Giflib.Results.Result := Giflib.Results.Success;
      Context : constant Giflib.Errors.Diagnostic_Context :=
        (Source_Position => Giflib.Errors.Source_Position_At (19),
         Block => Giflib.Image_Data_Block,
         Frame => Giflib.Errors.Frame_At (3),
         others => <>);
      Expected : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.Truncated_Block, Context);
      Bad : constant Giflib.Results.Result := Giflib.Results.Failure (Expected);
   begin
      Assert (Giflib.Results.Status_Of (Good) = Giflib.Results.Ok,
              "success has the wrong status");
      Assert (Giflib.Results.Status_Of (Bad) = Giflib.Results.Failed,
              "failure has the wrong status");
      Assert (Bad.First_Error.Code = Giflib.Errors.Truncated_Block, "failure lost its error code");
      Assert (Bad.First_Error.Context.Source_Position.Value = 19, "failure lost its source offset");
      Assert (Bad.First_Error.Context.Frame.Present
              and then Bad.First_Error.Context.Frame.Value = 3,
              "failure lost its frame ordinal");
   end Results_Preserve_First_Error;

   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Context : constant Giflib.Errors.Diagnostic_Context :=
        (Source_Position => Giflib.Errors.Source_Position_At (31),
         Destination_Position => Giflib.Errors.Destination_Position_At (7),
         Block => Giflib.Image_Data_Block,
         Extension_Label => Giflib.Errors.Extension_Label_At (16#F9#),
         Frame => Giflib.Errors.Frame_At (4),
         LZW => Giflib.Errors.LZW_At (299, 9, 17),
         Expected => 12,
         Actual => 13,
         Limit => Giflib.LZW_Work_Limit,
         Underlying_Code => Giflib.Errors.Underlying_Code_At (5));
      Item : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.LZW_Invalid_Code, Context);
      Zero_Position : constant Giflib.Errors.Error :=
        Giflib.Errors.Make
          (Giflib.Errors.Invalid_Block,
           (Source_Position => Giflib.Errors.Source_Position_At (0),
            Frame => Giflib.Errors.Frame_At (0),
            others => <>));
      Absent_Positions : constant Giflib.Errors.Error :=
        Giflib.Errors.Make
          (Giflib.Errors.Invalid_Block,
           (Frame => (Present => False),
            others => <>));
      Absent_Warning_Positions : constant Giflib.Errors.Warning :=
        Giflib.Errors.Make_Warning
          (Giflib.Errors.Generic_Warning,
           Giflib.Errors.Informational,
           (Frame => (Present => False),
            others => <>));
   begin
      for Code in Giflib.Errors.Error_Code loop
         Assert (Giflib.Errors.Identifier_For (Code)'Length > 4, "empty or malformed stable identifier");
      end loop;
      Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Invalid_Signature) = "gif.invalid_signature",
              "signature identifier changed");
      Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Limit_Exceeded) = "gif.limit.exceeded",
              "limit identifier changed");
      Assert
        (Item.Context.Source_Position.Value = 31
         and then Item.Context.Destination_Position.Value = 7,
         "offset context was lost");
      Assert
        (Item.Context.Source_Position.State = Giflib.Errors.Position_Available
         and then Item.Context.Destination_Position.State =
           Giflib.Errors.Position_Available
         and then Item.Context.Frame.Present,
         "nonzero diagnostic positions were not marked present");
      Assert
        (Zero_Position.Context.Source_Position.State =
           Giflib.Errors.Position_Available
         and then Zero_Position.Context.Source_Position.Value = 0
         and then Zero_Position.Context.Frame.Present
         and then Zero_Position.Context.Frame.Value = 0,
         "zero-valued diagnostic positions cannot be represented");
      Assert
        (Absent_Positions.Context.Source_Position.State =
           Giflib.Errors.Position_Not_Checked
         and then Absent_Positions.Context.Destination_Position.State =
           Giflib.Errors.Position_Not_Checked
         and then not Absent_Positions.Context.Frame.Present,
         "diagnostic presence was inferred from field values");
      Assert
        (Absent_Warning_Positions.Context.Source_Position.State =
           Giflib.Errors.Position_Not_Checked
         and then Absent_Warning_Positions.Context.Destination_Position.State =
           Giflib.Errors.Position_Not_Checked
         and then not Absent_Warning_Positions.Context.Frame.Present,
         "warning presence was inferred from field values");
      Assert (Item.Context.LZW.Present and then Item.Context.LZW.Code_Value = 299,
              "LZW context was lost");
      Assert (Item.Context.Limit = Giflib.LZW_Work_Limit, "limit context was lost");
   end Error_Identifiers_And_Context;

   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      L : constant Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   begin
      Assert (L.Max_Logical_Width = 16_384, "unexpected default width limit");
      Assert (L.Max_Logical_Height = 16_384, "unexpected default height limit");
      Assert (L.Max_Canvas_Pixels > 0, "canvas pixel limit disabled");
      Assert (L.Max_Canvas_Bytes > 0, "canvas byte limit disabled");
      Assert (L.Max_Frames > 0, "frame limit disabled");
      Assert (L.Max_Frame_Pixels > 0, "frame pixel limit disabled");
      Assert (L.Max_Total_Decoded_Frame_Pixels > 0, "total decoded pixel limit disabled");
      Assert (L.Max_Compressed_Bytes > 0, "compressed byte limit disabled");
      Assert (L.Max_Extensions > 0, "extension count limit disabled");
      Assert (L.Max_Retained_Metadata_Bytes > 0, "metadata limit disabled");
      Assert (L.Max_Per_Extension_Bytes > 0, "per-extension limit disabled");
      Assert (L.Max_Allocation_Bytes > 0, "allocation limit disabled");
      Assert (L.Max_Output_Bytes > 0, "output limit disabled");
      Assert (L.Max_LZW_Work > 0, "LZW work limit disabled");
      Assert (L.Max_Quantization_Work > 0, "quantization work limit disabled");
      Assert (L.Max_Optimization_Work > 0, "optimization work limit disabled");
      Assert (L.Max_Warning_Records > 0, "warning limit disabled");
      Assert (L.Max_Compositor_Snapshot_Bytes > 0, "snapshot limit disabled");
   end Defaults_Cover_Every_Limit;

   procedure Helpers_And_Warnings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Left : Giflib.Palettes.Palette;
      Right : Giflib.Palettes.Palette;
      Context : constant Giflib.Errors.Diagnostic_Context :=
        (Source_Position => Giflib.Errors.Source_Position_At (7),
         Frame => Giflib.Errors.Frame_At (2),
         others => <>);
      Warning : constant Giflib.Errors.Warning :=
        Giflib.Errors.Make_Warning
          (Giflib.Errors.Recovery_Applied, Giflib.Errors.Recovery, Context);
      Code_Only : constant Giflib.Results.Result :=
        Giflib.Results.Failure (Giflib.Errors.Invalid_State);
   begin
      Assert (Giflib.Images.Bytes_Per_Pixel (Giflib.Indexed_8) = 1
              and then Giflib.Images.Bytes_Per_Pixel (Giflib.RGB_24) = 3
              and then Giflib.Images.Bytes_Per_Pixel (Giflib.BGR_24) = 3
              and then Giflib.Images.Bytes_Per_Pixel (Giflib.RGBA_32) = 4
              and then Giflib.Images.Bytes_Per_Pixel (Giflib.BGRA_32) = 4,
              "pixel-format byte widths are wrong");

      Assert (Giflib.Palettes.Is_Encodable_Length (2)
              and then Giflib.Palettes.Is_Encodable_Length (256)
              and then not Giflib.Palettes.Is_Encodable_Length (0)
              and then not Giflib.Palettes.Is_Encodable_Length (3),
              "encodable palette lengths are wrong");
      Left.Length := 2;
      Left.Colors (0) := (1, 2, 3);
      Left.Colors (1) := (4, 5, 6);
      Right := Left;
      Right.Colors (2) := (7, 8, 9);
      Assert (Giflib.Palettes.Contains (Left, 1)
              and then not Giflib.Palettes.Contains (Left, 2)
              and then Giflib.Palettes.Same_Entries (Left, Right),
              "palette bounds or active-entry equality is wrong");
      Right.Colors (1) := (9, 9, 9);
      Assert (not Giflib.Palettes.Same_Entries (Left, Right),
              "different active palette entries compared equal");
      Right := Left;
      Right.Length := 1;
      Assert (not Giflib.Palettes.Same_Entries (Left, Right),
              "different palette lengths compared equal");

      for Code in Giflib.Errors.Warning_Code loop
         Assert (Giflib.Errors.Identifier_For (Code)'Length > 4,
                 "empty or malformed warning identifier");
      end loop;
      Assert (Warning.Code = Giflib.Errors.Recovery_Applied
              and then Warning.Severity = Giflib.Errors.Recovery
              and then Warning.Context.Source_Position.Value = 7
              and then Warning.Context.Frame.Present
              and then Warning.Context.Frame.Value = 2,
              "warning construction lost severity or context");
      Assert (Code_Only.First_Error.Code = Giflib.Errors.Invalid_State,
              "code-only failure construction lost its error");
      Assert (not Giflib.Errors.Is_Fatal
                (Giflib.Errors.Make (Giflib.Errors.No_Error))
              and then Giflib.Errors.Is_Fatal
                (Giflib.Errors.Make (Giflib.Errors.Invalid_State)),
              "fatal-error classification is wrong");
   end Helpers_And_Warnings;
end Giflib.Testing.Test_Foundation;
