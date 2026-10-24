with AUnit.Assertions;

with Giflib;
with Giflib.Capabilities;
with Giflib.Errors;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Version;
with Giflib_API_Consumer;

package body Giflib_Testing.Test_Foundation is
   use AUnit.Assertions;
   use type Giflib.Byte_Count;
   use type Giflib.Coordinate;
   use type Giflib.Destination_Offset;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Frame_Ordinal;
   use type Giflib.Image_Height;
   use type Giflib.Image_Width;
   use type Giflib.Limit_Kind;
   use type Giflib.LZW_Code;
   use type Giflib.Pixel_Count;
   use type Giflib.Results.Status;
   use type Giflib.Source_Offset;

   procedure Root_And_Consumer_Compile (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("foundation");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Root_And_Consumer_Compile'Access, "foundation.public_consumer");
      Register_Routine (T, Results_Preserve_First_Error'Access, "foundation.results.status_and_error");
      Register_Routine (T, Error_Identifiers_And_Context'Access, "foundation.errors.context");
      Register_Routine (T, Defaults_Cover_Every_Limit'Access, "foundation.limits.defaults");
   end Register_Tests;

   procedure Root_And_Consumer_Compile (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Giflib_API_Consumer.Version = "0.1.0-dev", "consumer sees the wrong version");
      Assert (Giflib.Version.Current = Giflib_API_Consumer.Version, "version constants disagree");
      Assert (Giflib_API_Consumer.Streams_Available, "memory streams must be advertised");
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
   end Root_And_Consumer_Compile;

   procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Good : constant Giflib.Results.Result := Giflib.Results.Success;
      Context : constant Giflib.Errors.Diagnostic_Context :=
        (Source => 19, Block => Giflib.Image_Data_Block, Frame => 3, others => <>);
      Expected : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.Truncated_Block, Context);
      Bad : constant Giflib.Results.Result := Giflib.Results.Failure (Expected);
   begin
      Assert (Good.State = Giflib.Results.Ok, "success has the wrong status");
      Assert (Bad.State = Giflib.Results.Failed, "failure has the wrong status");
      Assert (Bad.First_Error.Code = Giflib.Errors.Truncated_Block, "failure lost its error code");
      Assert (Bad.First_Error.Context.Source = 19, "failure lost its source offset");
      Assert (Bad.First_Error.Context.Frame = 3, "failure lost its frame ordinal");
   end Results_Preserve_First_Error;

   procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Context : constant Giflib.Errors.Diagnostic_Context :=
        (Source => 31,
         Destination => 7,
         Block => Giflib.Image_Data_Block,
         Extension_Label => 16#F9#,
         Frame => 4,
         LZW_Code_Value => 299,
         LZW_Width => 9,
         LZW_Code_Ordinal => 17,
         Has_LZW_Context => True,
         Expected => 12,
         Actual => 13,
         Limit => Giflib.LZW_Work_Limit,
         Underlying_Code => 5,
         Has_Underlying_Code => True);
      Item : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.LZW_Invalid_Code, Context);
   begin
      for Code in Giflib.Errors.Error_Code loop
         Assert (Giflib.Errors.Identifier_For (Code)'Length > 4, "empty or malformed stable identifier");
      end loop;
      Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Invalid_Signature) = "gif.invalid_signature",
              "signature identifier changed");
      Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Limit_Exceeded) = "gif.limit.exceeded",
              "limit identifier changed");
      Assert (Item.Context.Source = 31 and then Item.Context.Destination = 7, "offset context was lost");
      Assert (Item.Context.Has_LZW_Context and then Item.Context.LZW_Code_Value = 299,
              "LZW context was lost");
      Assert (Item.Context.Limit = Giflib.LZW_Work_Limit, "limit context was lost");
   end Error_Identifiers_And_Context;

   procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      L : constant Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   begin
      Assert (L.Max_Logical_Width > 0, "width limit disabled");
      Assert (L.Max_Logical_Height > 0, "height limit disabled");
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
      Assert (L.Max_Diagnostic_Events > 0, "diagnostic limit disabled");
      Assert (L.Max_Compositor_Snapshot_Bytes > 0, "snapshot limit disabled");
   end Defaults_Cover_Every_Limit;
end Giflib_Testing.Test_Foundation;
