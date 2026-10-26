with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Project_Tools.Ada_Source;
with Project_Tools.Alire_Manifests;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;

package body Giflib_Tooling is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;
   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);

   procedure Fail (Message : String) is
   begin
      Project_Tools.Release_Checks.Fail ("giflib tooling: " & Message);
   end Fail;

   function Lower (Value : String) return String is
      Result : String := Value;
   begin
      for Ch of Result loop
         Ch := Ada.Characters.Handling.To_Lower (Ch);
      end loop;
      return Result;
   end Lower;

   function Ends_With (Value : String; Suffix : String) return Boolean is
     (Project_Tools.Text.Ends_With (Lower (Value), Lower (Suffix)));

   function Scrub_Ada (Value : String) return String is
      Result : Unbounded_String;
      Index : Integer := Value'First;
      In_Comment : Boolean := False;
      In_String : Boolean := False;
   begin
      while Index <= Value'Last loop
         if In_Comment then
            if Value (Index) = ASCII.LF then
               In_Comment := False;
               Append (Result, ' ');
            end if;
         elsif In_String then
            if Value (Index) = '"' then
               if Index < Value'Last and then Value (Index + 1) = '"' then
                  Index := Index + 1;
               else
                  In_String := False;
               end if;
            end if;
            Append (Result, ' ');
         elsif Value (Index) = '"' then
            In_String := True;
            Append (Result, ' ');
         elsif Value (Index) = '-'
           and then Index < Value'Last
           and then Value (Index + 1) = '-'
         then
            In_Comment := True;
            Append (Result, ' ');
            Index := Index + 1;
         else
            Append (Result, Value (Index));
         end if;
         Index := Index + 1;
      end loop;
      return Lower (To_String (Result));
   end Scrub_Ada;

   function Compact (Value : String) return String is
      Result : Unbounded_String;
      Pending_Space : Boolean := False;
   begin
      for Ch of Value loop
         if Ch in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Pending_Space := Length (Result) > 0;
         else
            if Pending_Space then
               Append (Result, ' ');
               Pending_Space := False;
            end if;
            Append (Result, Ch);
         end if;
      end loop;
      return To_String (Result);
   end Compact;

   procedure Scan_Statements
     (Text : String;
      Process : not null access procedure (Statement : String))
   is
      Clean : constant String := Scrub_Ada (Text);
      First : Integer := Clean'First;
   begin
      for Index in Clean'Range loop
         if Clean (Index) = ';' then
            if Index > First then
               declare
                  Statement : constant String :=
                    Compact (Clean (First .. Index - 1));
               begin
                  if Statement /= "" then
                     Process (Statement);
                  end if;
               end;
            end if;
            First := Index + 1;
         end if;
      end loop;
   end Scan_Statements;

   function Source_Files (Root : String) return Files.Path_List is
     (Files.List_Tree (Files.Join (Root, "src")));

   procedure Check_Library_Interface (Root : String) is
      Project_Text : constant String :=
        Files.Read_Raw_File (Files.Join (Root, "giflib.gpr"));
      Marker : constant String := "for Library_Interface use";
      Start : constant Natural := Project_Tools.Text.Index (Project_Text, Marker);
      Actual : String_Vectors.Vector;
      Expected : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("Giflib"),
         To_Unbounded_String ("Giflib.Animations"),
         To_Unbounded_String ("Giflib.Capabilities"),
         To_Unbounded_String ("Giflib.Cleanup"),
         To_Unbounded_String ("Giflib.Decoding"),
         To_Unbounded_String ("Giflib.Encoding"),
         To_Unbounded_String ("Giflib.Errors"),
         To_Unbounded_String ("Giflib.Frames"),
         To_Unbounded_String ("Giflib.Images"),
         To_Unbounded_String ("Giflib.Limits"),
         To_Unbounded_String ("Giflib.Metadata"),
         To_Unbounded_String ("Giflib.Optimization"),
         To_Unbounded_String ("Giflib.Palettes"),
         To_Unbounded_String ("Giflib.Quantization"),
         To_Unbounded_String ("Giflib.Results"),
         To_Unbounded_String ("Giflib.Streams"),
         To_Unbounded_String ("Giflib.Version"),
         To_Unbounded_String ("Giflib.Internal"),
         To_Unbounded_String ("Giflib.Internal.Blocks"),
         To_Unbounded_String ("Giflib.Internal.Borrow_Guards"),
         To_Unbounded_String ("Giflib.Internal.Budget_Arithmetic"),
         To_Unbounded_String ("Giflib.Internal.Cleanup"),
         To_Unbounded_String ("Giflib.Internal.Decoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Encoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Interlacing"),
         To_Unbounded_String ("Giflib.Internal.LZW"),
         To_Unbounded_String ("Giflib.Internal.LZW_Arithmetic"),
         To_Unbounded_String ("Giflib.Internal.LZW_Decoder_Dictionary"),
         To_Unbounded_String ("Giflib.Internal.LZW_Encoding"),
         To_Unbounded_String ("Giflib.Internal.LZW_Encoder_Dictionary"),
         To_Unbounded_String ("Giflib.Internal.Metadata_Store"),
         To_Unbounded_String ("Giflib.Internal.Owned_Arrays"),
         To_Unbounded_String ("Giflib.Internal.Owned_Buffers"),
         To_Unbounded_String ("Giflib.Internal.Owned_Objects"),
         To_Unbounded_String ("Giflib.Internal.Owned_Vectors"),
         To_Unbounded_String ("Giflib.Internal.Ownership"),
         To_Unbounded_String ("Giflib.Internal.Ownership_Arithmetic"),
         To_Unbounded_String
           ("Giflib.Internal.Quantization_Buffer_Arithmetic"),
         To_Unbounded_String ("Giflib.Internal.Quantization_Dithering"),
         To_Unbounded_String ("Giflib.Internal.Quantization_Palette"),
         To_Unbounded_String ("Giflib.Internal.Quantization_Storage"),
         To_Unbounded_String ("Giflib.Internal.Work_Budgets")];
      Empty : constant Project_Tools.Ada_Source.String_List := [1 .. 0 => <>];
      Decoding_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Decoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Ownership")];
      Encoding_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Encoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Ownership")];
      Quantization_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Ownership"),
         To_Unbounded_String ("Giflib.Internal.Quantization_Storage")];
      Public_Specs : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("giflib.ads"),
         To_Unbounded_String ("giflib-animations.ads"),
         To_Unbounded_String ("giflib-capabilities.ads"),
         To_Unbounded_String ("giflib-cleanup.ads"),
         To_Unbounded_String ("giflib-errors.ads"),
         To_Unbounded_String ("giflib-frames.ads"),
         To_Unbounded_String ("giflib-images.ads"),
         To_Unbounded_String ("giflib-limits.ads"),
         To_Unbounded_String ("giflib-metadata.ads"),
         To_Unbounded_String ("giflib-optimization.ads"),
         To_Unbounded_String ("giflib-palettes.ads"),
         To_Unbounded_String ("giflib-results.ads"),
         To_Unbounded_String ("giflib-streams.ads"),
         To_Unbounded_String ("giflib-version.ads")];
   begin
      if Start = 0 then
         Fail ("library interface declaration is missing");
      end if;
      declare
         Index : Natural := Start + Marker'Length;
      begin
         while Index <= Project_Text'Last loop
            if Project_Text (Index) = '"' then
               declare
                  Last : Natural := Index + 1;
               begin
                  while Last <= Project_Text'Last
                    and then Project_Text (Last) /= '"'
                  loop
                     Last := Last + 1;
                  end loop;
                  if Last > Project_Text'Last then
                     Fail ("unterminated library-interface unit name");
                  end if;
                  Actual.Append
                    (To_Unbounded_String (Project_Text (Index + 1 .. Last - 1)));
                  Index := Last;
               end;
            elsif Project_Text (Index) = ';'
              and then Index > Project_Text'First
              and then Project_Text (Index - 1) = ')'
            then
               exit;
            end if;
            Index := Index + 1;
         end loop;
      end;
      if Natural (Actual.Length) /= Expected'Length then
         Fail ("library interface unit count changed without review");
      end if;
      for Index in Expected'Range loop
         if Actual (Index) /= Expected (Index) then
            Fail ("library interface order changed without review");
         end if;
      end loop;
      for Name of Public_Specs loop
         Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
           (Files.Join (Files.Join (Root, "src"), To_String (Name)),
            "Giflib.Internal", Empty, Quiet => True);
      end loop;
      Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
        (Files.Join (Root, "src/giflib-decoding.ads"),
         "Giflib.Internal", Decoding_Allowed, Quiet => True);
      Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
        (Files.Join (Root, "src/giflib-encoding.ads"),
         "Giflib.Internal", Encoding_Allowed, Quiet => True);
      Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
        (Files.Join (Root, "src/giflib-quantization.ads"),
         "Giflib.Internal", Quantization_Allowed, Quiet => True);
   exception
      when Program_Error =>
         Fail ("library interface or public dependency manifest changed");
   end Check_Library_Interface;

   procedure Check_Internal_Dependencies (Root : String) is
      Empty : constant Project_Tools.Ada_Source.String_List := [1 .. 0 => <>];
   begin
      for Path of Source_Files (Root) loop
         declare
            Name : constant String := Ada.Directories.Simple_Name (To_String (Path));
         begin
            if Project_Tools.Text.Starts_With (Lower (Name), "giflib-internal-")
              and then (Ends_With (Name, ".ads") or else Ends_With (Name, ".adb"))
            then
               Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
                 (To_String (Path), "Giflib.Decoding", Empty, Quiet => True);
               Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
                 (To_String (Path), "Giflib.Encoding", Empty, Quiet => True);
               Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
                 (To_String (Path), "Giflib.Quantization", Empty, Quiet => True);
            end if;
         end;
      end loop;
   exception
      when Program_Error =>
         Fail ("internal package depends upward on a public codec facade");
   end Check_Internal_Dependencies;

   procedure Check_Ownership_Instances (Root : String) is
      Count : Natural := 0;
      Renamed : Boolean := False;
      procedure Inspect (Statement : String) is
      begin
         if Project_Tools.Text.Starts_With (Statement, "package ")
           and then
             (Project_Tools.Text.Contains (Statement, " is new owned_arrays")
              or else Project_Tools.Text.Contains
                (Statement, " is new giflib.internal.owned_arrays")
              or else Project_Tools.Text.Contains (Statement, " is new owned_objects")
              or else Project_Tools.Text.Contains
                (Statement, " is new giflib.internal.owned_objects"))
         then
            Count := Count + 1;
         elsif Project_Tools.Text.Contains (Statement, " renames owned_arrays")
           or else Project_Tools.Text.Contains (Statement, " renames owned_objects")
           or else Project_Tools.Text.Contains
             (Statement, " renames giflib.internal.owned_arrays")
           or else Project_Tools.Text.Contains
             (Statement, " renames giflib.internal.owned_objects")
         then
            Renamed := True;
         end if;
      end Inspect;
      Required : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String
           ("giflib-internal-lzw.ads:package Workspace_Ownership is new Owned_Objects"),
         To_Unbounded_String
           ("giflib-internal-lzw_encoding.ads:package Workspace_Ownership is new Owned_Objects"),
         To_Unbounded_String
           ("giflib-internal-metadata_store.ads:package Payload_Storage is new Owned_Arrays"),
         To_Unbounded_String
           ("giflib-internal-metadata_store.ads:package Extension_Storage is new Owned_Arrays"),
         To_Unbounded_String
           ("giflib-internal-owned_buffers.ads:package Storage is new Owned_Arrays"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:package Histogram_Ownership is new Owned_Objects"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:package Nearest_Cache_Ownership is new Owned_Objects"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:package Error_Ownership is new Owned_Arrays")];
   begin
      for Path of Source_Files (Root) loop
         if Ends_With (To_String (Path), ".ads")
           or else Ends_With (To_String (Path), ".adb")
         then
            Scan_Statements (Files.Read_Raw_File (To_String (Path)), Inspect'Access);
         end if;
      end loop;
      if Count /= Required'Length or else Renamed then
         Fail ("production ownership-container instances need safety review");
      end if;
      for Item of Required loop
         declare
            Value : constant String := To_String (Item);
            Split : constant Natural := Project_Tools.Text.Index (Value, ":");
         begin
            if Split = 0
              or else not Files.File_Contains
                (Files.Join (Root, "src/" & Value (Value'First .. Split - 1)),
                 Value (Split + 1 .. Value'Last))
            then
               Fail ("reviewed ownership instance is missing");
            end if;
         end;
      end loop;
   end Check_Ownership_Instances;

   function Line_Count (Text : String) return Natural is
      Result : Natural := (if Text = "" then 0 else 1);
   begin
      for Ch of Text loop
         if Ch = ASCII.LF then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Line_Count;

   procedure Check_Test_Layout (Root : String) is
      Test_Root : constant String := Files.Join (Root, "tests/src");
   begin
      for Path of Files.List_Tree (Test_Root, "*.adb") loop
         declare
            Name : constant String := Ada.Directories.Simple_Name (To_String (Path));
            Parent : constant String := Ada.Directories.Containing_Directory (To_String (Path));
            Text : constant String := Files.Read_Raw_File (To_String (Path));
         begin
            if Parent = Test_Root
              and then Project_Tools.Text.Contains (Scrub_Ada (Text), "separate (")
            then
               Fail ("test subunit is outside tests/src/subunits: " & Name);
            elsif Parent = Test_Root
              and then Project_Tools.Text.Starts_With
                (Lower (Name), "giflib-testing-test_")
              and then Line_Count (Text) > 500
            then
               Fail ("test-case parent body exceeds 500 lines: " & Name);
            end if;
         end;
      end loop;
   end Check_Test_Layout;

   function Is_Whole_Object_Actual (Statement : String) return Boolean is
     (Project_Tools.Text.Contains (Statement, "(object)")
      or else Project_Tools.Text.Contains (Statement, "(object,")
      or else Project_Tools.Text.Contains (Statement, ", object)")
      or else Project_Tools.Text.Contains (Statement, ", object,"));

   function Allowed_Whole_Object_Call (Statement : String) return Boolean is
      Allowed : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("session_transitions."),
         To_Unbounded_String ("resource_management.release"),
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
         To_Unbounded_String ("add_warning (object"),
         To_Unbounded_String ("fail (object"),
         To_Unbounded_String ("deliver_event (object"),
         To_Unbounded_String ("prepare_frame (object"),
         To_Unbounded_String ("validate_frame_request (object"),
         To_Unbounded_String ("validate_frame_output (object"),
         To_Unbounded_String ("reject_request (object"),
         To_Unbounded_String ("reject_frame_request (object"),
         To_Unbounded_String ("fail_frame (object"),
         To_Unbounded_String ("write_header (object"),
         To_Unbounded_String ("write_raw (object"),
         To_Unbounded_String ("write_palette (object"),
         To_Unbounded_String ("write_chunk (object"),
         To_Unbounded_String ("write_prefix (object"),
         To_Unbounded_String ("invalid_transition (object"),
         To_Unbounded_String ("output_variant_error (object"),
         To_Unbounded_String ("input_position (object"),
         To_Unbounded_String ("complete_frame (object"),
         To_Unbounded_String ("check_trailing_data (object"),
         To_Unbounded_String ("has_extension_capacity (object"),
         To_Unbounded_String ("start_retention (object"),
         To_Unbounded_String ("retain_chunk (object"),
         To_Unbounded_String ("read_fixed_block (object"),
         To_Unbounded_String ("read_sub_blocks (object"),
         To_Unbounded_String ("truncated (object"),
         To_Unbounded_String ("check_fixed_payload (object"),
         To_Unbounded_String ("read_graphic_control (object"),
         To_Unbounded_String ("read_application (object"),
         To_Unbounded_String ("read_plain_text (object"),
         To_Unbounded_String ("read_variable_extension (object"),
         To_Unbounded_String ("read_extension (object"),
         To_Unbounded_String ("fill_background (object"),
         To_Unbounded_String ("allocation_result (object"),
         To_Unbounded_String ("quantizer_bytes (object"),
         To_Unbounded_String ("outer_maximum (object"),
         To_Unbounded_String ("prepare (object"),
         To_Unbounded_String ("complete (object"),
         To_Unbounded_String ("validate (object"),
         To_Unbounded_String ("complete_extension (object"),
         To_Unbounded_String ("initialize (object"),
         To_Unbounded_String ("add_extension (object"),
         To_Unbounded_String ("add_extension_exact (object"),
         To_Unbounded_String ("add_decoded_extension (object"),
         To_Unbounded_String ("add_decoded_extension_exact (object")];
   begin
      for Item of Allowed loop
         if Project_Tools.Text.Contains (Statement, To_String (Item)) then
            return True;
         end if;
      end loop;
      return False;
   end Allowed_Whole_Object_Call;

   function Transition_Violation
     (Statement : String;
      Fields : Files.Name_List;
      Mutators : Files.Name_List) return Boolean
   is
      Assignment : constant Natural := Project_Tools.Text.Index (Statement, ":=");
      Left_Start : Natural := Statement'First;
      Has_Protected_Actual : Boolean := False;
      Mutating_Name : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("mutate"), To_Unbounded_String ("update"),
         To_Unbounded_String ("set"), To_Unbounded_String ("reset"),
         To_Unbounded_String ("clear"), To_Unbounded_String ("assign"),
         To_Unbounded_String ("replace"), To_Unbounded_String ("change")];
   begin
      if Assignment > 0 then
         declare
            Prefix : constant String :=
              Statement (Statement'First .. Assignment - 1);
            Then_At : constant Natural :=
              Ada.Strings.Fixed.Index
                (Prefix, " then ", Going => Ada.Strings.Backward);
            Else_At : constant Natural :=
              Ada.Strings.Fixed.Index
                (Prefix, " else ", Going => Ada.Strings.Backward);
            Arrow_At : constant Natural :=
              Ada.Strings.Fixed.Index
                (Prefix, "=>", Going => Ada.Strings.Backward);
         begin
            if Arrow_At > 0
              and then Arrow_At >= Then_At and then Arrow_At >= Else_At
            then
               Left_Start := Arrow_At + 2;
            elsif Then_At > 0 and then Then_At >= Else_At then
               Left_Start := Then_At + 6;
            elsif Else_At > 0 then
               Left_Start := Else_At + 6;
            end if;
         end;
      end if;
      for Field of Fields loop
         declare
            Token : constant String := "object." & Lower (To_String (Field));
         begin
            if Assignment > 0
              and then Project_Tools.Text.Contains
                (Statement (Left_Start .. Assignment - 1), Token)
            then
               return True;
            elsif Project_Tools.Text.Contains (Statement, "renames " & Token) then
               return True;
            elsif Project_Tools.Text.Contains (Statement, "(" & Token)
              or else Project_Tools.Text.Contains (Statement, ", " & Token)
            then
               Has_Protected_Actual := True;
            end if;
         end;
      end loop;
      for Name of Mutators loop
         if Project_Tools.Text.Contains
           (Statement, "state_arithmetic." & Lower (To_String (Name)) & " (")
         then
            return True;
         end if;
      end loop;
      if Project_Tools.Text.Contains (Statement, "renames state_arithmetic") then
         return True;
      end if;
      for Prefix of Mutating_Name loop
         declare
            Name : constant String := To_String (Prefix);
            Has_Mutating_Callee : constant Boolean :=
              Project_Tools.Text.Starts_With (Statement, Name & " (")
              or else Project_Tools.Text.Starts_With (Statement, Name & "_")
              or else Project_Tools.Text.Contains (Statement, "." & Name & " (")
              or else Project_Tools.Text.Contains (Statement, "." & Name & "_")
              or else Project_Tools.Text.Contains (Statement, " " & Name & " (")
              or else Project_Tools.Text.Contains (Statement, " " & Name & "_");
         begin
         if (Has_Protected_Actual or else Is_Whole_Object_Actual (Statement))
           and then Has_Mutating_Callee
           and then not Project_Tools.Text.Contains
             (Statement, "session_transitions.")
         then
            return True;
         end if;
         end;
      end loop;
      return Is_Whole_Object_Actual (Statement)
        and then not Allowed_Whole_Object_Call (Statement)
        and then not Project_Tools.Text.Contains (Statement, "function ")
        and then not Project_Tools.Text.Contains (Statement, "procedure ");
   end Transition_Violation;

   procedure Check_Transitions (Root : String) is
      Decoder_Fields : constant Files.Name_List :=
        [To_Unbounded_String ("Current_State"), To_Unbounded_String ("Options"),
         To_Unbounded_String ("Constraints"), To_Unbounded_String ("Header_Data"),
         To_Unbounded_String ("Frames_Seen"), To_Unbounded_String ("Total_Decoded_Pixels"),
         To_Unbounded_String ("Total_Compressed_Bytes"), To_Unbounded_String ("Extensions_Seen"),
         To_Unbounded_String ("Pending_Control"), To_Unbounded_String ("Has_Pending_Control"),
         To_Unbounded_String ("Pending_Frame"), To_Unbounded_String ("Has_Pending_Frame"),
         To_Unbounded_String ("Loop_Data"), To_Unbounded_String ("Snapshot_Rectangle"),
         To_Unbounded_String ("Previous_Rectangle"), To_Unbounded_String ("Previous_Control"),
         To_Unbounded_String ("Has_Previous_Frame"), To_Unbounded_String ("Warnings"),
         To_Unbounded_String ("Stored_Warnings"), To_Unbounded_String ("Diagnostic")];
      Encoder_Fields : constant Files.Name_List :=
        [To_Unbounded_String ("Current_State"), To_Unbounded_String ("Options"),
         To_Unbounded_String ("Constraints"), To_Unbounded_String ("Screen"),
         To_Unbounded_String ("Global_Palette"), To_Unbounded_String ("Has_Global_Palette"),
         To_Unbounded_String ("Loop_Data"), To_Unbounded_String ("Header_Written"),
         To_Unbounded_String ("Frames_Written"), To_Unbounded_String ("Extensions_Written"),
         To_Unbounded_String ("Bytes_Written"),
         To_Unbounded_String ("Compressed_Bytes_Written"),
         To_Unbounded_String ("Diagnostic")];
      Decoder_Mutators : constant Files.Name_List :=
        [To_Unbounded_String ("Initialize"), To_Unbounded_String ("Reset"),
         To_Unbounded_String ("Header_Read"), To_Unbounded_String ("Frame_Discovered"),
         To_Unbounded_String ("Await_Frame_Decision"), To_Unbounded_String ("Begin_Frame"),
         To_Unbounded_String ("Frame_Completed"), To_Unbounded_String ("Complete_Stream"),
         To_Unbounded_String ("Cancel"), To_Unbounded_String ("Fail"),
         To_Unbounded_String ("Finalize")];
      Encoder_Mutators : constant Files.Name_List :=
        [To_Unbounded_String ("Initialize"), To_Unbounded_String ("Define_Screen"),
         To_Unbounded_String ("Accept_Data"), To_Unbounded_String ("Record_Extension"),
         To_Unbounded_String ("Frame_Accepted"), To_Unbounded_String ("Complete"),
         To_Unbounded_String ("Cancel"), To_Unbounded_String ("Fail"),
         To_Unbounded_String ("Finalize")];

      procedure Scan_Family
        (Prefix : String; Owner : String; Fields : Files.Name_List;
         Mutators : Files.Name_List)
      is
      begin
         for Path of Source_Files (Root) loop
            declare
               Name : constant String := Lower (Ada.Directories.Simple_Name (To_String (Path)));
               procedure Inspect (Statement : String) is
               begin
                  if Transition_Violation (Statement, Fields, Mutators) then
                     Fail
                       ("session state mutation escaped transition owner: " &
                        Name & ": " & Statement);
                  end if;
               end Inspect;
            begin
               if Project_Tools.Text.Starts_With (Name, Prefix)
                 and then Ends_With (Name, ".adb") and then Name /= Owner
               then
                  Scan_Statements (Files.Read_Raw_File (To_String (Path)), Inspect'Access);
               end if;
            end;
         end loop;
      end Scan_Family;
   begin
      if not Transition_Violation
        ("value := mutate (0, object.current_state)", Decoder_Fields,
         Decoder_Mutators)
        or else not Transition_Violation
          ("resource_management.update (object)", Decoder_Fields, Decoder_Mutators)
        or else not Transition_Violation
          ("sneak (object)", Decoder_Fields, Decoder_Mutators)
      then
         Fail ("transition checker self-test failed");
      end if;
      Scan_Family
        ("giflib-decoding", "giflib-decoding-session_transitions.adb",
         Decoder_Fields, Decoder_Mutators);
      Scan_Family
        ("giflib-encoding", "giflib-encoding-session_transitions.adb",
         Encoder_Fields, Encoder_Mutators);
   end Check_Transitions;

   procedure Check_API_Boundaries (Root : String) is
      Gprbuild : constant String := Processes.Locate_Command ("gprbuild");

      procedure Require_Rejected
        (Project : String; Expected : String; Failure : String)
      is
         Result : constant Processes.Captured_Process :=
           Processes.Capture_Command
             (Gprbuild,
              Processes.Arguments
                ([Processes.Argument ("-q"), Processes.Argument ("-p"),
                  Processes.Argument ("-P"),
                  Processes.Argument (Files.Join (Root, Project))]),
              Err_To_Out => True);
      begin
         if Result.Status = 0 then
            Fail (Failure & " unexpectedly compiled");
         elsif not Project_Tools.Text.Contains
           (Lower (To_String (Result.Output)), Lower (Expected))
         then
            Fail (Failure & " failed for an unexpected reason");
         end if;
      end Require_Rejected;
   begin
      Processes.Require_Command
        ("gprbuild", "giflib tooling: gprbuild is required", Quiet => True);
      Processes.Run
        ("public API compile", Root, Gprbuild,
         Processes.Arguments
           ([Processes.Argument ("-q"), Processes.Argument ("-p"),
             Processes.Argument ("-P"),
             Processes.Argument (Files.Join (Root, "tests/public_api.gpr"))]),
         Quiet => True);
      Require_Rejected
        ("tests/private_api_rejection.gpr", "private child unit",
         "private API probe");
      Require_Rejected
        ("tests/ownership_safety_rejection.gpr",
         "aspect ""no_controlled_parts"" applied to controlled type",
         "ownership safety probe");
   end Check_API_Boundaries;

   procedure Validate (Root : String) is
      Checks : constant Project_Tools.Release_Checks.Checker :=
        Project_Tools.Release_Checks.Create (Root);
   begin
      Project_Tools.Release_Checks.Require_Text
        (Checks, "alire.toml", "gnat_native = ""^15""", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/alire.toml", "gnat_native = ""^15""", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "giflib.gpr", "with ""giflib_build.gpr"";", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/giflib_whitebox.gpr",
         "with ""../giflib_build.gpr"";", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/public_api.gpr", "with ""../giflib.gpr"";",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/unit_tests.gpr", "with ""giflib_whitebox.gpr"";",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/tools.gpr", "with ""../giflib.gpr"";",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/alire.toml", "executables = [""giflib_tests""]",
         Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/alire.toml", "project-files = [""unit_tests.gpr""]",
         Quiet => True);
      Project_Tools.Alire_Manifests.Require_Workspace_Pin
        (Files.Join (Root, "tests/alire.toml"), "project_tools",
         "../../project_tools", Quiet => True);
      Check_Library_Interface (Root);
      Check_Internal_Dependencies (Root);
      Check_Ownership_Instances (Root);
      Check_Test_Layout (Root);
      Check_Transitions (Root);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File => Files.Join (Root, "tests/unit_tests.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory => Files.Join (Root, "tests/src/test_mains"),
         Quiet => True);
      Project_Tools.Release_Checks.Require_GPR_Main_Inventory
        (Project_File => Files.Join (Root, "tests/tools.gpr"),
         Documentation_File => Files.Join (Root, "docs/IMPLEMENTATION_PLAN.md"),
         Source_Directory => Files.Join (Root, "tests/src/mains"),
         Quiet => True);
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir => Files.Join (Root, "tests/src"),
         Spec_Pattern => "giflib-testing-test_*.ads",
         Suite_Path => Files.Join (Root, "tests/src/giflib-testing-suite.adb"),
         Suite_Add_Prefix => "new ", Suite_Add_Suffix => ".Test",
         Required_Stem_Suffix => "", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/test_mains/giflib_tests.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_check.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_samples.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_generate_fixtures.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_external_checks.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_benchmark.adb",
         "with Project_Tools.", Quiet => True);
      Project_Tools.Release_Checks.Require_Text
        (Checks, "tests/src/mains/giflib_fuzz.adb",
         "with Project_Tools.", Quiet => True);
      Check_API_Boundaries (Root);
   exception
      when Program_Error =>
         raise;
      when others =>
         Fail ("validation raised an unexpected exception");
   end Validate;
end Giflib_Tooling;
