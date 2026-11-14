with Ada.Strings.Unbounded;

package body Giflib_Tooling.Transition_Policy_Family_Call_Data is
   use Ada.Strings.Unbounded;
   type Allowance is record
      Unit_Name : Unbounded_String;
      Callee : Unbounded_String;
   end record;
   type Allowance_Array is array (Positive range <>) of Allowance;
   function Permit (Unit_Name : String; Callee : String) return Allowance is
     ((To_Unbounded_String (Unit_Name), To_Unbounded_String (Callee)));
   Allowed_Calls : constant Allowance_Array :=
     [Permit ("giflib-decoding", "failure_handling.input_position_of"),
      Permit ("giflib-decoding", "failure_handling.invalid_state"),
      Permit ("giflib-decoding", "failure_handling.fail"),
      Permit ("giflib-decoding", "failure_sequence.fail"),
      Permit ("giflib-decoding", "failure_handling.variant_error"),
      Permit ("giflib-decoding", "output_validation.validate"),
      Permit ("giflib-decoding", "output_validation.deliver"),
      Permit ("giflib-decoding", "failure_handling.record_warning"),
      Permit
        ("giflib-decoding", "lifecycle_sequence.prepare_initialization"),
      Permit ("giflib-decoding", "lifecycle_sequence.release_and_cancel"),
      Permit ("giflib-decoding", "lifecycle_sequence.finalize_session"),
      Permit ("giflib-decoding", "trailing_data.validate"),
      Permit ("giflib-decoding", "resource_management.ensure_canvas"),
      Permit
        ("giflib-decoding", "resource_management.ensure_frame_scratch"),
      Permit
        ("giflib-decoding", "resource_management.ensure_lzw_workspace"),
      Permit ("giflib-decoding", "resource_management.ensure_snapshot"),
      Permit ("giflib-decoding", "frame_pipeline.prepare"),
      Permit ("giflib-decoding", "frame_pipeline.finish"),
      Permit ("giflib-decoding", "frame_pipeline.start_decode"),
      Permit ("giflib-decoding", "frame_pipeline.start_skip"),
      Permit ("giflib-decoding", "frame_pipeline.decode_indices"),
      Permit ("giflib-decoding", "frame_pipeline.composite"),
      Permit ("giflib-decoding", "frame_pipeline.skip_data"),
      Permit ("giflib-decoding", "frame_lifecycle.prepare"),
      Permit ("giflib-decoding", "frame_lifecycle.finish"),
      Permit ("giflib-decoding", "frame_lifecycle.start_decode"),
      Permit ("giflib-decoding", "frame_lifecycle.start_skip"),
      Permit ("giflib-decoding", "frame_execution.decode_indices"),
      Permit ("giflib-decoding", "frame_execution.composite"),
      Permit ("giflib-decoding", "frame_execution.skip_data"),
      Permit ("giflib-decoding", "frame_compositing.composite"),
      Permit ("giflib-decoding", "frame_compositing.setup_canvas"),
      Permit ("giflib-decoding", "frame_data.decode_indices"),
      Permit ("giflib-decoding", "frame_data.decode_scratch"),
      Permit ("giflib-decoding", "frame_data.skip"),
      Permit ("giflib-decoding", "extensions.read"),
      Permit ("giflib-decoding", "retention.start"),
      Permit ("giflib-decoding", "retention.append"),
      Permit ("giflib-decoding", "retention.finish"),
      Permit ("giflib-decoding", "transport.truncated"),
      Permit ("giflib-decoding", "transport.read_fixed_block"),
      Permit ("giflib-decoding", "transport.read_sub_blocks"),
      Permit ("giflib-decoding", "internal.blocks.initialize"),
      Permit ("giflib-decoding", "internal.blocks.read_data"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.overlay_frame_scratch"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.decode_indices"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.decode_frame_scratch"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.fill_canvas_rectangle"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.restore_snapshot"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.image_operations.capture_snapshot"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.metadata_operations.start"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.metadata_operations.append"),
      Permit
        ("giflib-decoding",
         "internal.decoder_storage.metadata_operations.finish"),
      Permit ("giflib-decoding", "internal.container.read_header"),
      Permit
        ("giflib-decoding", "internal.container.read_image_descriptor"),
      Permit ("giflib-decoding", "internal.image_data.skip"),
      Permit
        ("giflib-decoding", "internal.decoder_storage.ensure_frame_scratch"),
      Permit ("giflib-decoding", "internal.decoder_storage.ensure_lzw"),
      Permit ("giflib-decoding", "internal.decoder_storage.ensure_canvas"),
      Permit ("giflib-decoding", "internal.decoder_storage.ensure_snapshot"),
      Permit ("giflib-encoding", "failure_handling.invalid_state"),
      Permit ("giflib-encoding", "failure_handling.fail"),
      Permit ("giflib-encoding", "failure_sequence.fail"),
      Permit ("giflib-encoding", "failure_handling.reject"),
      Permit ("giflib-encoding", "failure_handling.reject_frame"),
      Permit ("giflib-encoding", "failure_handling.fail_frame_request"),
      Permit
        ("giflib-encoding", "lifecycle_sequence.prepare_initialization"),
      Permit ("giflib-encoding", "lifecycle_sequence.release_and_cancel"),
      Permit ("giflib-encoding", "lifecycle_sequence.finalize_session"),
      Permit ("giflib-encoding", "request_validation.has_extension_room"),
      Permit ("giflib-encoding", "request_validation.validate_screen"),
      Permit
        ("giflib-encoding", "request_validation.validate_global_palette"),
      Permit ("giflib-encoding", "request_validation.validate_loop_count"),
      Permit ("giflib-encoding", "request_validation.validate_frame"),
      Permit ("giflib-encoding", "wire_output.write"),
      Permit ("giflib-encoding", "wire_output.write_color_table"),
      Permit
        ("giflib-encoding", "resource_management.ensure_truecolor_pixels"),
      Permit
        ("giflib-encoding", "resource_management.ensure_lzw_workspace"),
      Permit
        ("giflib-encoding", "resource_management.quantization_constraints"),
      Permit
        ("giflib-encoding", "resource_management.normalize_quantization_error"),
      Permit ("giflib-encoding", "frame_pipeline.add_indexed"),
      Permit ("giflib-encoding", "frame_pipeline.add_stored"),
      Permit ("giflib-encoding", "extensions.add"),
      Permit ("giflib-encoding", "extensions.add_exact"),
      Permit ("giflib-encoding", "validation.request"),
      Permit ("giflib-encoding", "emission.emit"),
      Permit
        ("giflib-encoding",
         "internal.encoder_storage.frame_operations.encode_lzw"),
      Permit
        ("giflib-encoding",
         "internal.encoder_storage.frame_operations.encode_stored_lzw"),
      Permit ("giflib-encoding", "internal.container_writer.signature"),
      Permit
        ("giflib-encoding", "internal.container_writer.logical_screen"),
      Permit
        ("giflib-encoding", "internal.container_writer.palette_length")];

   procedure Visit
     (Process : not null access procedure
        (Unit_Prefix : String; Callee : String)) is
   begin
      for Item of Allowed_Calls loop
         Process (To_String (Item.Unit_Name), To_String (Item.Callee));
      end loop;
   end Visit;
end Giflib_Tooling.Transition_Policy_Family_Call_Data;
