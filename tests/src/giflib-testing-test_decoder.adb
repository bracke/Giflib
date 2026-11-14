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

   procedure Decodes_Independent_One_Pixel_GIF (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Rejects_Constrained_Header
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Rejects_Constrained_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Retries_Constrained_Frame_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Retries_Incorrect_Indexed_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Retries_Incorrect_RGBA_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Decodes_Local_Interlaced_GIF89a (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Failure_Preserves_First_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure State_Cancel_Reset_And_Unsupported (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Skips_Indexed_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Independent_Decoders_Interleave (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Expands_Frame_Rectangle_To_RGBA (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Decodes_Independent_File_Corpus (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Giflib.Testing.Test_Decoder;
