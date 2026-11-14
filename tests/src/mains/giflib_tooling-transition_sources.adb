with Giflib_Tooling.Text_Case;
with Giflib_Tooling.Transition_Declarations;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Transition_Storage;

package body Giflib_Tooling.Transition_Sources is
   package Source_Units renames Giflib_Tooling.Source_Units;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Declarations renames Giflib_Tooling.Transition_Declarations;

   procedure Build
     (Object : in out Repository;
      Snapshot : Snapshots.Snapshot;
      Cached_Sources : Caches.Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget)
   is
      Build_Storage :
        Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
          Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
      procedure Include (Path : String; Name : String) is
         Normalized : constant String := Text_Case.Lower (Name);
         Unit_Storage :
           Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
             Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
         begin
            if not Source_Names.Is_Ada_Source (Normalized) then
               return;
            elsif Object.Unit_Indices.Contains (Normalized) then
               Fail ("duplicate source unit basename: " & Normalized);
            end if;
            declare
               Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
               Callable_Names :
                 Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
               procedure Cache (Parsed : Source.Parsed_Source) is
                  Clause : constant Source_Units.Separate_Clause :=
                    Source.Separate_Clause_Of (Parsed);
               begin
                  Declarations.Collect_Types
                    (Parsed, Type_Names, Budget, Unit_Storage);
                  Declarations.Collect_Visible
                    (Parsed, Callable_Names, Budget, Unit_Storage);
                  Giflib_Tooling.Transition_Storage.Charge_Indexed_Unit
                    (Unit_Storage, Normalized, Path, Clause);
                  Object.Units.Append
                    (Indexed_Unit'
                       (Name => To_Unbounded_String (Normalized),
                        Path => To_Unbounded_String (Path),
                        Clause => Clause,
                        Source_Length => Caches.Source_Length
                          (Cached_Sources, Path),
                        Type_Names => Type_Names,
                        Callable_Names => Callable_Names));
               end Cache;
            begin
               Budgets.Charge_Scan
                 (Budget,
                  Caches.Source_Length (Cached_Sources, Path));
               Caches.Inspect
                 (Cached_Sources, Path, Cache'Access);
               begin
                  Object.Unit_Indices.Insert
                    (Normalized, Object.Units.Last_Index);
               exception
                  when others =>
                     Object.Units.Delete_Last;
                     raise;
               end;
               Giflib_Tooling.Validation_Storage_Budgets.Transfer
                 (Unit_Storage, Build_Storage);
            end;
      end Include;
   begin
      if not Object.Units.Is_Empty or else not Object.Unit_Indices.Is_Empty then
         raise Program_Error with "transition source repository already built";
      end if;
      begin
         Snapshots.Walk (Snapshot, "src", Include'Access);
         Giflib_Tooling.Validation_Storage_Budgets.Commit (Build_Storage);
      exception
         when Giflib_Tooling.Validation_Storage_Budgets.Limit_Exceeded =>
            Object.Unit_Indices.Clear;
            Object.Units.Clear;
            raise Input_Error with "transition index storage budget exhausted";
         when others =>
            Object.Unit_Indices.Clear;
            Object.Units.Clear;
            raise;
      end;
   end Build;

   function Count (Object : Repository) return Natural is
     (Natural (Object.Units.Length));

   function Name_At (Object : Repository; Index : Positive) return String is
     (To_String (Object.Units (Index).Name));

   function Contains (Object : Repository; Name : String) return Boolean is
     (Object.Unit_Indices.Contains (Name));

   procedure Inspect
     (Object : Repository;
      Cached_Sources : Caches.Cache;
      Index : Positive;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Source_Units.Separate_Clause)) is
      Item : constant Indexed_Unit_Vectors.Constant_Reference_Type :=
        Object.Units.Constant_Reference (Index);
      procedure Deliver (Parsed : Source.Parsed_Source) is
      begin
         Process (To_String (Item.Name), Parsed, Item.Clause);
      end Deliver;
   begin
      Budgets.Charge_Scan (Budget, Item.Source_Length);
      Caches.Inspect
        (Cached_Sources, To_String (Item.Path), Deliver'Access);
   end Inspect;

   procedure Inspect
     (Object : Repository;
      Cached_Sources : Caches.Cache;
      Name : String;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Source_Units.Separate_Clause)) is
   begin
      if Object.Unit_Indices.Contains (Name) then
         Inspect
           (Object, Cached_Sources, Object.Unit_Indices.Element (Name), Budget,
            Process);
      else
         raise Input_Error with "source unit is not indexed: " & Name;
      end if;
   end Inspect;

   procedure Visit_Declarations
     (Object : Repository;
      Name : String;
      Process : not null access procedure
        (Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
         Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector))
   is
   begin
      if not Object.Unit_Indices.Contains (Name) then
         raise Input_Error with "source unit is not indexed: " & Name;
      end if;
      declare
         Item : constant Indexed_Unit_Vectors.Constant_Reference_Type :=
           Object.Units.Constant_Reference
             (Object.Unit_Indices.Element (Name));
      begin
         Process (Item.Type_Names, Item.Callable_Names);
      end;
   end Visit_Declarations;

end Giflib_Tooling.Transition_Sources;
