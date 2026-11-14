with Giflib_Tooling.Repository_Identity;

package body Giflib_Tooling.Repository_Snapshots is
   package Repository_Identity renames Giflib_Tooling.Repository_Identity;

   function Root (Object : Snapshot) return String is
     (To_String (Object.Repository_Root));

   function Parsing_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Parsing_Limits is
     (Object.Configuration.Parsing);

   function Cache_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Cache_Limits is
     (Object.Configuration.Cache);

   function Validation_Limits_Of
     (Object : Snapshot) return Giflib_Tooling.Source_Limits.Validation_Limits is
     (Object.Configuration.Validation);

   function Canonical (Object : Snapshot; Path : String) return String is
     (Repository_Identity.Resolve_Within (Root (Object), Path));

   function Build
     (Root_Path : String;
      Profile : Capture_Profile := Complete_Repository;
      Limits : Giflib_Tooling.Source_Limits.Analysis_Limits :=
        Giflib_Tooling.Source_Limits.Default_Analysis_Limits;
      Cleanup_State : access Giflib_Tooling.Repository_Searches.Cleanup_Status :=
        null)
      return Snapshot is separate;

   procedure Inspect_Text
     (Object : Snapshot;
      Path : String;
      Process : not null access procedure (Text : String))
   is
      Key : constant String := Canonical (Object, Path);
   begin
      if Key = "" or else not Object.Indices.Contains (Key) then
         raise Input_Error with
           "path is not present in repository snapshot: " & Path;
      end if;
      declare
         Item : constant Entry_Vectors.Constant_Reference_Type :=
           Object.Entries.Constant_Reference (Object.Indices.Element (Key));
      begin
         Process (Item.Text);
      end;
   end Inspect_Text;

   function Contains (Object : Snapshot; Path : String) return Boolean is
      Key : constant String := Canonical (Object, Path);
   begin
      return Key /= "" and then Object.Indices.Contains (Key);
   end Contains;

   function Source_Length (Object : Snapshot; Path : String) return Natural is
      Key : constant String := Canonical (Object, Path);
   begin
      if Key = "" or else not Object.Indices.Contains (Key) then
         raise Input_Error with
           "path is not present in repository snapshot: " & Path;
      end if;
      return Object.Entries (Object.Indices.Element (Key)).Text'Length;
   end Source_Length;

   procedure Walk
     (Object : Snapshot;
      Directory : String;
      Process : not null access procedure (Path : String; Name : String))
   is
      Prefix : constant String := Canonical (Object, Directory);
   begin
      if Prefix = "" or else not Object.Directories.Contains (Prefix) then
         raise Input_Error with
           "directory is not present in repository snapshot: " & Directory;
      end if;
      for Index of Object.Directories (Prefix) loop
         declare
            Item : constant Entry_Vectors.Constant_Reference_Type :=
              Object.Entries.Constant_Reference (Index);
         begin
            Process (Item.Path, Item.Name);
         end;
      end loop;
   end Walk;
end Giflib_Tooling.Repository_Snapshots;
