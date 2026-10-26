with Ada.Directories;
with Ada.Containers;
with Ada.Strings.Unbounded;

with Project_Tools.Ada_Source;
with Project_Tools.Files;
with Project_Tools.Text;

with Giflib_Tooling.Source_Model;

package body Giflib_Tooling.Architecture is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Giflib_Tooling.Source_Model.Token_Kind;
   package Files renames Project_Tools.Files;
   package Source renames Giflib_Tooling.Source_Model;

   function Ends_With (Value : String; Suffix : String) return Boolean is
     (Project_Tools.Text.Ends_With
        (Source.Lower (Value), Source.Lower (Suffix)));

   function Source_Files (Root : String) return Files.Path_List is
     (Files.List_Tree (Files.Join (Root, "src")));

   procedure Check_Library_Interface (Root : String) is
      Tokens : constant Source.Token_Vectors.Vector :=
        Source.Lex (Files.Read_Raw_File (Files.Join (Root, "giflib.gpr")));
      Actual : Source.Name_Vectors.Vector;
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
      Found : Boolean := False;
   begin
      if not Tokens.Is_Empty then
         for Index in Tokens.First_Index .. Tokens.Last_Index loop
            if not Found
              and then Source.Image (Tokens (Index)) = "library_interface"
            then
               Found := True;
            elsif Found and then Tokens (Index).Kind = Source.String_Literal then
               Actual.Append (Tokens (Index).Text);
            elsif Found and then Source.Image (Tokens (Index)) = ";" then
               exit;
            end if;
         end loop;
      end if;
      if not Found or else Natural (Actual.Length) /= Expected'Length then
         Fail ("library interface unit inventory changed without review");
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
            if Project_Tools.Text.Starts_With
              (Source.Lower (Name), "giflib-internal-")
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
      Found : Source.Name_Vectors.Vector;
      Required : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String
           ("giflib-internal-lzw.ads:workspace_ownership:owned_objects"),
         To_Unbounded_String
           ("giflib-internal-lzw_encoding.ads:workspace_ownership:owned_objects"),
         To_Unbounded_String
           ("giflib-internal-metadata_store.ads:payload_storage:owned_arrays"),
         To_Unbounded_String
           ("giflib-internal-metadata_store.ads:extension_storage:owned_arrays"),
         To_Unbounded_String
           ("giflib-internal-owned_buffers.ads:storage:owned_arrays"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:histogram_ownership:owned_objects"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:nearest_cache_ownership:owned_objects"),
         To_Unbounded_String
           ("giflib-internal-quantization_storage.ads:error_ownership:owned_arrays")];

      procedure Inspect_File (Path : String) is
         Name : constant String := Source.Lower (Ada.Directories.Simple_Name (Path));
         procedure Inspect (Statement : Source.Token_Vectors.Vector) is
            Package_At : Natural := 0;
         begin
            if Statement.Length >= 4 then
               if Source.Image (Statement (Statement.First_Index)) = "package" then
                  Package_At := Statement.First_Index;
               elsif Statement.Length >= 5
                 and then Source.Image (Statement (Statement.First_Index)) = "private"
                 and then Source.Image (Statement (Statement.First_Index + 1)) =
                   "package"
               then
                  Package_At := Statement.First_Index + 1;
               end if;
            end if;
            if Package_At > 0
              and then Statement (Package_At + 1).Kind = Source.Identifier
            then
               for Index in Package_At + 2 .. Statement.Last_Index loop
                  if Source.Image (Statement (Index)) = "is"
                    and then Index < Statement.Last_Index
                    and then Source.Image (Statement (Index + 1)) = "new"
                  then
                     if Index + 2 <= Statement.Last_Index then
                        for Open in Index + 2 .. Statement.Last_Index loop
                           if Source.Image (Statement (Open)) = "(" then
                              declare
                                 Generic_Name : constant String :=
                                   Source.Join_Callee (Statement, Open);
                                 Simple : constant String :=
                                   (if Generic_Name = "giflib.internal.owned_arrays"
                                    then "owned_arrays"
                                    elsif Generic_Name = "giflib.internal.owned_objects"
                                    then "owned_objects"
                                    else Generic_Name);
                              begin
                                 if Simple in "owned_arrays" | "owned_objects" then
                                    Found.Append
                                      (To_Unbounded_String
                                         (Name & ":" &
                                          Source.Image
                                            (Statement (Package_At + 1)) &
                                          ":" & Simple));
                                 end if;
                              end;
                              exit;
                           end if;
                        end loop;
                     end if;
                     exit;
                  elsif Source.Image (Statement (Index)) = "renames" then
                     if Index < Statement.Last_Index then
                        for Cursor in Index + 1 .. Statement.Last_Index loop
                           if Source.Image (Statement (Cursor)) in
                             "owned_arrays" | "owned_objects"
                           then
                              Fail
                                ("ownership generic aliases need safety review");
                           end if;
                        end loop;
                     end if;
                  end if;
               end loop;
            end if;
         end Inspect;
      begin
         Source.Scan_Statements (Files.Read_Raw_File (Path), Inspect'Access);
      end Inspect_File;
   begin
      for Path of Source_Files (Root) loop
         if Ends_With (To_String (Path), ".ads")
           or else Ends_With (To_String (Path), ".adb")
         then
            Inspect_File (To_String (Path));
         end if;
      end loop;
      if Natural (Found.Length) /= Required'Length then
         Fail ("production ownership-container instances need safety review");
      end if;
      for Item of Required loop
         if not Source.Contains (Found, To_String (Item)) then
            Fail ("reviewed ownership instance is missing");
         end if;
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
            Parent : constant String :=
              Ada.Directories.Containing_Directory (To_String (Path));
            Text : constant String := Files.Read_Raw_File (To_String (Path));
         begin
            if Parent = Test_Root
              and then Source.Contains_Code (Text, "separate (")
            then
               Fail ("test subunit is outside tests/src/subunits: " & Name);
            elsif Parent = Test_Root
              and then Project_Tools.Text.Starts_With
                (Source.Lower (Name), "giflib-testing-test_")
              and then Line_Count (Text) > 500
            then
               Fail ("test-case parent body exceeds 500 lines: " & Name);
            end if;
         end;
      end loop;
   end Check_Test_Layout;

   procedure Validate (Root : String) is
   begin
      Check_Library_Interface (Root);
      Check_Internal_Dependencies (Root);
      Check_Ownership_Instances (Root);
      Check_Test_Layout (Root);
   end Validate;
end Giflib_Tooling.Architecture;
