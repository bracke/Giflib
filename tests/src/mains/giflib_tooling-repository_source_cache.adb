with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Repository_Identity;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Source_Limits;

package body Giflib_Tooling.Repository_Source_Cache is
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Identity renames Giflib_Tooling.Repository_Identity;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Source renames Giflib_Tooling.Source_Model;

   function Key_For (Object : Cache; Path : String) return String is
     (Identity.Resolve_Within (To_String (Object.Repository_Root), Path));

   function Build
     (Repository : Snapshots.Snapshot;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Parsing : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Limits : Giflib_Tooling.Source_Limits.Cache_Limits) return Cache
   is
      Cache_Budget : Giflib_Tooling.Work_Budgets.Budget :=
        Giflib_Tooling.Work_Budgets.Child
          (Budget, Limits.Maximum_Cache_Work);
      procedure Populate (Object : in out Cache) is
         procedure Include (Path : String; Name : String) is
         begin
            if not Source_Names.Is_Ada_Source (Name) then
               return;
            end if;
            declare
               Length : constant Natural :=
                 Snapshots.Source_Length (Repository, Path);
               Available : constant Natural :=
                 (Limits.Maximum_Cached_Model_Units -
                    Object.Model_Units) / 2;
               Storage : Giflib_Tooling.Model_Storage_Budgets.Budget
                 (Available);
               procedure Parse_Text (Text : String) is
                  Parsed : constant Source.Parsed_Source :=
                    Source.Parse (Text, Parsing, Cache_Budget, Storage);
                  Units : constant Natural :=
                    Giflib_Tooling.Model_Storage_Budgets.Used (Storage);
                  Scan_Work : constant Natural :=
                    Source.Storage_Work (Parsed);
               begin
                  if Units /= Source.Storage_Units (Parsed) then
                     raise Program_Error with
                       "parsed source storage accounting mismatch for " &
                       Path & ": charged" & Natural'Image (Units) &
                       ", measured" &
                       Natural'Image (Source.Storage_Units (Parsed));
                  end if;
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Cache_Budget, Scan_Work);
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Cache_Budget, Units);
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Cache_Budget, Path'Length);
                  Giflib_Tooling.Work_Budgets.Charge (Cache_Budget);
                  Object.Sources.Append
                    (Cached_Source'
                       (Path => To_Unbounded_String (Path),
                        Parsed => Parsed,
                        Text_Length => Text'Length));
                  Giflib_Tooling.Work_Budgets.Charge_Scan
                    (Cache_Budget, Path'Length);
                  Giflib_Tooling.Work_Budgets.Charge (Cache_Budget);
                  Object.Indices.Insert
                    (Path, Object.Sources.Last_Index);
                  Object.Model_Units := Object.Model_Units + Units;
               end Parse_Text;
            begin
               Giflib_Tooling.Work_Budgets.Charge_Scan
                 (Cache_Budget, Length);
               Giflib_Tooling.Work_Budgets.Charge_Scan
                 (Cache_Budget, Length);
               Snapshots.Inspect_Text (Repository, Path, Parse_Text'Access);
            exception
               when Giflib_Tooling.Model_Storage_Budgets.Limit_Exceeded =>
                  raise Input_Error with
                    "parsed source cache storage-unit limit exceeded";
            end;
         end Include;
      begin
         Snapshots.Walk (Repository, Snapshots.Root (Repository), Include'Access);
      end Populate;
   begin
      return Result : Cache do
         Result.Repository_Root := To_Unbounded_String
           (Snapshots.Root (Repository));
         Populate (Result);
      end return;
   end Build;

   function Build
     (Repository : Snapshots.Snapshot;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Cache is
   begin
      declare
         Parsing : constant Giflib_Tooling.Source_Limits.Parsing_Limits :=
           Snapshots.Parsing_Limits_Of (Repository);
         Limits : constant Giflib_Tooling.Source_Limits.Cache_Limits :=
           Snapshots.Cache_Limits_Of (Repository);
      begin
         return Build (Repository, Budget, Parsing, Limits);
      end;
   end Build;

   function Source_Length (Object : Cache; Path : String) return Natural is
      Key : constant String := Key_For (Object, Path);
   begin
      if not Object.Indices.Contains (Key) then
         raise Input_Error with "Ada source is not cached: " & Path;
      end if;
      return Object.Sources (Object.Indices.Element (Key)).Text_Length;
   end Source_Length;

   procedure Inspect
     (Object : Cache;
      Path : String;
      Process : not null access procedure (Parsed : Source.Parsed_Source))
   is
      Key : constant String := Key_For (Object, Path);
   begin
      if not Object.Indices.Contains (Key) then
         raise Input_Error with "Ada source is not cached: " & Path;
      end if;
      declare
         Item : constant Source_Vectors.Constant_Reference_Type :=
           Object.Sources.Constant_Reference (Object.Indices.Element (Key));
      begin
         Process (Item.Parsed);
      end;
   end Inspect;
end Giflib_Tooling.Repository_Source_Cache;
