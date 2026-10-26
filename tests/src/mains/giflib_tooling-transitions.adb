with Ada.Directories;
with Ada.Strings.Unbounded;

with Project_Tools.Files;
with Project_Tools.Text;

package body Giflib_Tooling.Transitions is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Source renames Giflib_Tooling.Source_Model;
   Session_Prefix : constant String := "session_transitions.";

   Allowed_Calls : constant array (Positive range <>) of Unbounded_String :=
     [To_Unbounded_String ("resource_management.release"),
      To_Unbounded_String ("resource_management.setup_canvas"),
      To_Unbounded_String ("resource_management.apply_previous_disposal"),
      To_Unbounded_String ("resource_management.save_snapshot"),
      To_Unbounded_String ("resource_management.ensure_frame_scratch"),
      To_Unbounded_String ("resource_management.ensure_lzw_workspace"),
      To_Unbounded_String ("resource_management.ensure_truecolor_pixels"),
      To_Unbounded_String ("resource_management.quantization_constraints"),
      To_Unbounded_String ("resource_management.normalize_quantization_error"),
      To_Unbounded_String ("frame_pipeline.add_indexed"),
      To_Unbounded_String ("frame_pipeline.add_stored"),
      To_Unbounded_String ("frame_pipeline.start_decode"),
      To_Unbounded_String ("frame_pipeline.start_skip"),
      To_Unbounded_String ("frame_pipeline.decode_scratch"),
      To_Unbounded_String ("frame_pipeline.decode_indices"),
      To_Unbounded_String ("extensions.read"),
      To_Unbounded_String ("extensions.add"),
      To_Unbounded_String ("extensions.add_exact"),
      To_Unbounded_String ("add_warning"),
      To_Unbounded_String ("fail"),
      To_Unbounded_String ("deliver_event"),
      To_Unbounded_String ("prepare_frame"),
      To_Unbounded_String ("validate_frame_request"),
      To_Unbounded_String ("validate_frame_output"),
      To_Unbounded_String ("reject_request"),
      To_Unbounded_String ("reject_frame_request"),
      To_Unbounded_String ("fail_frame"),
      To_Unbounded_String ("write_header"),
      To_Unbounded_String ("write_raw"),
      To_Unbounded_String ("write_palette"),
      To_Unbounded_String ("write_chunk"),
      To_Unbounded_String ("write_prefix"),
      To_Unbounded_String ("invalid_transition"),
      To_Unbounded_String ("output_variant_error"),
      To_Unbounded_String ("input_position"),
      To_Unbounded_String ("complete_frame"),
      To_Unbounded_String ("check_trailing_data"),
      To_Unbounded_String ("has_extension_capacity"),
      To_Unbounded_String ("start_retention"),
      To_Unbounded_String ("retain_chunk"),
      To_Unbounded_String ("read_fixed_block"),
      To_Unbounded_String ("read_sub_blocks"),
      To_Unbounded_String ("truncated"),
      To_Unbounded_String ("check_fixed_payload"),
      To_Unbounded_String ("read_graphic_control"),
      To_Unbounded_String ("read_application"),
      To_Unbounded_String ("read_plain_text"),
      To_Unbounded_String ("read_variable_extension"),
      To_Unbounded_String ("read_extension"),
      To_Unbounded_String ("fill_background"),
      To_Unbounded_String ("allocation_result"),
      To_Unbounded_String ("quantizer_bytes"),
      To_Unbounded_String ("outer_maximum"),
      To_Unbounded_String ("prepare"),
      To_Unbounded_String ("complete"),
      To_Unbounded_String ("validate"),
      To_Unbounded_String ("complete_extension"),
      To_Unbounded_String ("initialize"),
      To_Unbounded_String ("add_extension"),
      To_Unbounded_String ("add_extension_exact"),
      To_Unbounded_String ("add_decoded_extension"),
      To_Unbounded_String ("add_decoded_extension_exact"),
      To_Unbounded_String ("state_arithmetic.can_initialize"),
      To_Unbounded_String ("state_arithmetic.can_cancel"),
      To_Unbounded_String ("state_arithmetic.can_configure"),
      To_Unbounded_String ("state_arithmetic.can_define_screen"),
      To_Unbounded_String ("state_arithmetic.can_read_event"),
      To_Unbounded_String ("state_arithmetic.can_read_header"),
      To_Unbounded_String ("state_arithmetic.can_process_frame"),
      To_Unbounded_String ("state_arithmetic.can_accept_data"),
      To_Unbounded_String ("state_arithmetic.can_finish"),
      To_Unbounded_String ("arithmetic.can_append"),
      To_Unbounded_String ("arithmetic.appended_length"),
      To_Unbounded_String ("session_arithmetic.has_natural_capacity"),
      To_Unbounded_String ("geometry_arithmetic.analyze_rectangle"),
      To_Unbounded_String ("internal.budget_arithmetic.charge"),
      To_Unbounded_String ("errors.frame_at"),
      To_Unbounded_String ("byte_count"),
      To_Unbounded_String ("internal.geometry_arithmetic.area"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.overlay_frame_scratch"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.decode_indices"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.decode_frame_scratch"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.fill_canvas_rectangle"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.restore_snapshot"),
      To_Unbounded_String
        ("internal.decoder_storage.image_operations.capture_snapshot"),
      To_Unbounded_String
        ("internal.decoder_storage.metadata_operations.start"),
      To_Unbounded_String
        ("internal.decoder_storage.metadata_operations.append"),
      To_Unbounded_String
        ("internal.decoder_storage.metadata_operations.finish"),
      To_Unbounded_String
        ("internal.encoder_storage.frame_operations.encode_lzw"),
      To_Unbounded_String
        ("internal.encoder_storage.frame_operations.encode_stored_lzw"),
      To_Unbounded_String ("internal.container.read_header"),
      To_Unbounded_String ("internal.container.read_image_descriptor"),
      To_Unbounded_String ("internal.container_writer.signature"),
      To_Unbounded_String ("internal.container_writer.logical_screen"),
      To_Unbounded_String ("internal.container_writer.palette_length"),
      To_Unbounded_String ("internal.image_data.skip"),
      To_Unbounded_String ("internal.resource_diagnostics.allocation_error"),
      To_Unbounded_String ("internal.decoder_storage.ensure_frame_scratch"),
      To_Unbounded_String ("internal.decoder_storage.ensure_lzw"),
      To_Unbounded_String ("internal.decoder_storage.ensure_canvas"),
      To_Unbounded_String ("internal.decoder_storage.ensure_snapshot"),
      To_Unbounded_String ("palettes.contains"),
      To_Unbounded_String ("palettes.same_entries"),
      To_Unbounded_String ("colors"),
      To_Unbounded_String ("object.header_data.global_palette.colors"),
      To_Unbounded_String ("animations.raw_count"),
      To_Unbounded_String ("results.failure"),
      To_Unbounded_String ("pos")];

   function Allowed (Callee : String) return Boolean is
   begin
      if Callee'Length > Session_Prefix'Length
        and then Callee
          (Callee'First .. Callee'First + Session_Prefix'Length - 1) =
            Session_Prefix
      then
         return True;
      end if;
      for Item of Allowed_Calls loop
         if Callee = To_String (Item) then
            return True;
         end if;
      end loop;
      return False;
   end Allowed;

   function Is_Declaration
     (Statement : Source.Token_Vectors.Vector) return Boolean
   is
   begin
      if Statement.Is_Empty then
         return False;
      end if;
      return Source.Image (Statement (Statement.First_Index)) in
        "procedure" | "function";
   end Is_Declaration;

   function Violation
     (Statement : Source.Token_Vectors.Vector;
      Protected_Fields : Source.Name_Vectors.Vector) return Boolean
   is
      Assignment : Natural := 0;
      Left_Start : Positive :=
        (if Statement.Is_Empty then 1 else Statement.First_Index);
   begin
      if Statement.Is_Empty or else Is_Declaration (Statement) then
         return False;
      end if;
      for Index in Statement.First_Index .. Statement.Last_Index loop
         if Source.Image (Statement (Index)) = ":=" then
            Assignment := Index;
            exit;
         end if;
      end loop;
      if Assignment > 0 then
         for Index in Statement.First_Index .. Assignment - 1 loop
            if Source.Image (Statement (Index)) in "then" | "else" | "=>" then
               Left_Start := Index + 1;
            end if;
         end loop;
      end if;
      for Index in Statement.First_Index .. Statement.Last_Index loop
         if Source.Image (Statement (Index)) = "object" then
            if Index < Statement.Last_Index
              and then Source.Image (Statement (Index + 1)) = ":"
            then
               null;
            elsif Index + 2 <= Statement.Last_Index
              and then Source.Image (Statement (Index + 1)) = "."
              and then Source.Contains
                (Protected_Fields, Source.Image (Statement (Index + 2)))
            then
               if (Assignment > 0
                   and then Index >= Left_Start
                   and then Index < Assignment)
                 or else (Index > Statement.First_Index
                          and then Source.Image (Statement (Index - 1)) = "renames")
               then
                  return True;
               end if;
               declare
                  Callee : constant String :=
                    Source.Enclosing_Callee (Statement, Index);
               begin
                  if Callee /= "" and then not Allowed (Callee) then
                     return True;
                  end if;
               end;
            elsif Index = Statement.Last_Index
              or else Source.Image (Statement (Index + 1)) /= "."
            then
               declare
                  Callee : constant String :=
                    Source.Enclosing_Callee (Statement, Index);
               begin
                  if Callee /= "" and then not Allowed (Callee) then
                     return True;
                  end if;
               end;
            end if;
         end if;
      end loop;
      return False;
   end Violation;

   function Classified_Fields
     (Root : String;
      Spec : String;
      Type_Name : String;
      Exempt : Source.Name_Vectors.Vector) return Source.Name_Vectors.Vector
   is
      Actual : constant Source.Name_Vectors.Vector :=
        Source.Record_Fields
          (Files.Read_Raw_File (Files.Join (Root, Spec)), Type_Name);
      Result : Source.Name_Vectors.Vector;
   begin
      if Actual.Is_Empty then
         Fail ("cannot derive session fields for " & Type_Name);
      end if;
      for Name of Exempt loop
         if not Source.Contains (Actual, To_String (Name)) then
            Fail
              ("stale session-field exemption for " & Type_Name & ": " &
               To_String (Name));
         end if;
      end loop;
      for Name of Actual loop
         if not Source.Contains (Exempt, To_String (Name)) then
            Result.Append (Name);
         end if;
      end loop;
      if Natural (Result.Length) + Natural (Exempt.Length) /=
        Natural (Actual.Length)
      then
         Fail ("session fields are not classified exactly once for " & Type_Name);
      end if;
      return Result;
   end Classified_Fields;

   procedure Scan_Family
     (Root : String;
      Prefix : String;
      Owner : String;
      Fields : Source.Name_Vectors.Vector)
   is
   begin
      for Path of Files.List_Tree (Files.Join (Root, "src")) loop
         declare
            Name : constant String :=
              Source.Lower (Ada.Directories.Simple_Name (To_String (Path)));
            procedure Inspect (Statement : Source.Token_Vectors.Vector) is
            begin
               if Violation (Statement, Fields) then
                  Fail
                    ("session state mutation escaped transition owner: " & Name &
                     ": " & Source.Image (Statement));
               end if;
            end Inspect;
         begin
            if Project_Tools.Text.Starts_With (Name, Prefix)
              and then Project_Tools.Text.Ends_With (Name, ".adb")
              and then Name /= Owner
            then
               Source.Scan_Statements
                 (Files.Read_Raw_File (To_String (Path)), Inspect'Access);
            end if;
         end;
      end loop;
   end Scan_Family;

   procedure Validate (Root : String) is
      Decoder_Exempt : Source.Name_Vectors.Vector;
      Encoder_Exempt : Source.Name_Vectors.Vector;
   begin
      Decoder_Exempt.Append (To_Unbounded_String ("resources"));
      Decoder_Exempt.Append (To_Unbounded_String ("allocation_fault"));
      Encoder_Exempt.Append (To_Unbounded_String ("cleanup_state"));
      Encoder_Exempt.Append (To_Unbounded_String ("resources"));
      Encoder_Exempt.Append (To_Unbounded_String ("quantizer_data"));
      Encoder_Exempt.Append (To_Unbounded_String ("allocation_fault"));
      Scan_Family
        (Root, "giflib-decoding", "giflib-decoding-session_transitions.adb",
         Classified_Fields
           (Root, "src/giflib-decoding.ads", "decoder", Decoder_Exempt));
      Scan_Family
        (Root, "giflib-encoding", "giflib-encoding-session_transitions.adb",
         Classified_Fields
           (Root, "src/giflib-encoding.ads", "encoder", Encoder_Exempt));
   end Validate;
end Giflib_Tooling.Transitions;
