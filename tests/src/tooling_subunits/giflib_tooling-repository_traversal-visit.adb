separate (Giflib_Tooling.Repository_Traversal)
procedure Visit
  (State : in out Traversal_State;
   Directory : String;
   Depth : Natural;
   Process : not null access procedure
     (Path : String; Name : String; File : Handles.Owner);
   Before_Inspect : access procedure (Path : String))
is
   Search : Searches.Search (State.Search_Cleanup'Access);
   Item : Ada.Directories.Directory_Entry_Type;
   Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   Directory_File : Handles.Owner;
   Search_Location : Unbounded_String :=
     To_Unbounded_String (Directory);

   procedure Require_Directory_Identity
     (Mismatch : Diagnostics.Reason) is
   begin
      case Identity.Opened_Directory_Status
        (Directory_File, Directory)
      is
         when Identity.Identity_Verified =>
            null;
         when Identity.Identity_Mismatch =>
            Diagnostics.Raise_Input (Mismatch);
         when Identity.Verification_Unavailable =>
            Diagnostics.Raise_Input
              (Diagnostics.Identity_Verification_Unavailable);
      end case;
   end Require_Directory_Identity;
begin
   if not Discovery_IO.Exists
     (Directory, Diagnostics.Directory_Changed_During_Discovery)
   then
      Diagnostics.Raise_Input
        (Diagnostics.Directory_Changed_During_Discovery);
   elsif Discovery_IO.Canonical_Path
       (Directory, Diagnostics.Discovery_Directory_Identity_Changed) /=
         Directory
     or else Discovery_IO.Is_Symbolic_Link
       (Directory, Diagnostics.Discovery_Directory_Identity_Changed)
     or else not Identity.Is_Canonical_Within
       (To_String (State.Canonical_Root), Directory)
   then
      Diagnostics.Raise_Input
        (Diagnostics.Discovery_Directory_Identity_Changed);
   end if;
   if not Handles.Open_Read (Directory_File, Directory) then
      Diagnostics.Raise_Input (Diagnostics.Directory_Open_Failed);
   end if;
   declare
      Descriptor : constant String :=
        Identity.Descriptor_Path (Directory_File);
   begin
      Require_Directory_Identity
        (Diagnostics.Directory_Identity_Unverified);
      Search_Location := To_Unbounded_String (Descriptor);
   end;
   begin
      Searches.Start (Search, To_String (Search_Location));
      while Searches.More_Entries (Search) loop
         Searches.Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name not in "." | ".." then
               if State.Entry_Count >=
                 State.Discovery.Maximum_Discovery_Entries
               then
                  Diagnostics.Raise_Input
                    (Diagnostics.Discovery_Entry_Limit_Exceeded);
               end if;
               State.Entry_Count := State.Entry_Count + 1;
               Names.Append (To_Unbounded_String (Name));
            end if;
         end;
      end loop;
      Searches.Finish (Search);
   exception
      when Searches.Search_Failed =>
         Diagnostics.Raise_Input (Diagnostics.Directory_Search_Failed);
   end;
   if Searches.First_Cleanup_Status (Search) = Searches.Cleanup_Failed
   then
      Diagnostics.Raise_Input
        (Diagnostics.Directory_Search_Cleanup_Failed);
   end if;
   Require_Directory_Identity
     (Diagnostics.Directory_Changed_During_Discovery);
   Name_Sorting.Sort (Names);
   for Stored_Name of Names loop
      declare
         Name : constant String := To_String (Stored_Name);
         Logical_Path : constant String := Files.Join (Directory, Name);
         Path : constant String :=
           Files.Join (To_String (Search_Location), Name);
         Canonical_Entry : constant String :=
           Discovery_IO.Canonical_Path
             (Path,
              Diagnostics.Entry_Identity_Changed_During_Discovery);
         Kind : Ada.Directories.File_Kind;
         Entry_File : Handles.Owner;

         procedure Require_Entry_Identity is
         begin
            case Identity.Opened_File_Status
              (Entry_File, Canonical_Entry)
            is
               when Identity.Identity_Verified =>
                  null;
               when Identity.Identity_Mismatch =>
                  Diagnostics.Raise_Input
                    (Diagnostics.Entry_Identity_Changed_During_Discovery);
               when Identity.Verification_Unavailable =>
                  Diagnostics.Raise_Input
                    (Diagnostics.Identity_Verification_Unavailable);
            end case;
         end Require_Entry_Identity;
      begin
         if Discovery_IO.Is_Symbolic_Link
              (Logical_Path,
               Diagnostics.Entry_Identity_Changed_During_Discovery)
           or else Discovery_IO.Is_Symbolic_Link
              (Path,
               Diagnostics.Entry_Identity_Changed_During_Discovery)
         then
            Diagnostics.Raise_Input
              (Diagnostics.Entry_Identity_Changed_During_Discovery);
         elsif not Identity.Is_Canonical_Within
           (To_String (State.Canonical_Root), Canonical_Entry)
         then
            Diagnostics.Raise_Input
              (Diagnostics.Discovery_Escaped_Canonical_Root);
         end if;
         Kind := Discovery_IO.Kind
           (Canonical_Entry,
            Diagnostics.Entry_Identity_Changed_During_Discovery);
         if Kind = Ada.Directories.Ordinary_File then
            if not Handles.Open_Read (Entry_File, Path) then
               Diagnostics.Raise_Input (Diagnostics.Input_Open_Failed);
            end if;
            Require_Entry_Identity;
         end if;
         if Before_Inspect /= null then
            Before_Inspect (Logical_Path);
         end if;
         Require_Directory_Identity
           (Diagnostics.Directory_Changed_During_Discovery);
         if Discovery_IO.Is_Symbolic_Link
              (Logical_Path,
               Diagnostics.Entry_Identity_Changed_During_Discovery)
           or else Discovery_IO.Is_Symbolic_Link
              (Path,
               Diagnostics.Entry_Identity_Changed_During_Discovery)
           or else Discovery_IO.Canonical_Path
              (Path,
               Diagnostics.Entry_Identity_Changed_During_Discovery) /=
                 Canonical_Entry
         then
            Diagnostics.Raise_Input
              (Diagnostics.Entry_Identity_Changed_During_Discovery);
         elsif not Identity.Is_Canonical_Within
           (To_String (State.Canonical_Root), Canonical_Entry)
         then
            Diagnostics.Raise_Input
              (Diagnostics.Discovery_Escaped_Canonical_Root);
         else
            if Kind = Ada.Directories.Directory then
               if Depth >= State.Discovery.Maximum_Directory_Depth then
                  Diagnostics.Raise_Input
                    (Diagnostics.Directory_Depth_Limit_Exceeded);
               end if;
               Visit
                 (State, Canonical_Entry, Depth + 1, Process,
                  Before_Inspect);
            elsif Kind = Ada.Directories.Ordinary_File then
               Require_Entry_Identity;
               if State.File_Count >= State.Discovery.Maximum_Source_Files then
                  Diagnostics.Raise_Input
                    (Diagnostics.Source_File_Limit_Exceeded);
               end if;
               State.File_Count := State.File_Count + 1;
               declare
                  Length : constant Long_Integer :=
                    Handles.Length (Entry_File);
               begin
                  if Length < 0
                    or else Length >
                      Long_Integer
                        (State.Maximum_Source_Length)
                  then
                     Diagnostics.Raise_Input
                       (Diagnostics.File_Length_Limit_Exceeded);
                  end if;
               end;
               Process
                 (Canonical_Entry, Name, Entry_File);
               Require_Entry_Identity;
               if Discovery_IO.Canonical_Path
                 (Path,
                  Diagnostics.Entry_Identity_Changed_During_Discovery) /=
                    Canonical_Entry
               then
                  Diagnostics.Raise_Input
                    (Diagnostics.Entry_Identity_Changed_During_Discovery);
               end if;
            end if;
         end if;
      end;
   end loop;
   Require_Directory_Identity
     (Diagnostics.Directory_Changed_During_Discovery);
end Visit;
