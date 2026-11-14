with Giflib_Tooling.Source_Tokens;
with Ada.Containers;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Call_Analysis;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Architecture_Ownership is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Source renames Giflib_Tooling.Source_Model;
   package Scopes renames Giflib_Tooling.Scope_Analysis;
   use type Scopes.Declaration_Scope;
   package Calls renames Giflib_Tooling.Call_Analysis;
   use type Calls.Callee_Status;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;
   package Ownership_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_Type => String);

   procedure Validate
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Found : Ownership_Sets.Set;
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
         Name : constant String :=
           Text_Case.Lower (Ada.Directories.Simple_Name (Path));
         procedure Inspect
           (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
            Scope_At : Scopes.Declaration_Scope_Vectors.Vector) is
            Package_At : Natural := 0;
         begin
            if Statement.Length >= 4 then
               for Cursor in Statement.First_Index .. Statement.Last_Index - 2 loop
                  Giflib_Tooling.Work_Budgets.Charge (Budget);
                  if Giflib_Tooling.Source_Tokens.Image (Statement (Cursor)) = "package"
                    and then Giflib_Tooling.Source_Tokens.Kind_Of (Statement (Cursor + 1)) =
                      Giflib_Tooling.Source_Tokens.Identifier
                    and then Giflib_Tooling.Source_Tokens.Image (Statement (Cursor + 1)) /= "body"
                    and then
                      (Cursor = Statement.First_Index
                       or else Giflib_Tooling.Source_Tokens.Image (Statement (Cursor - 1)) /= "with")
                  then
                     Package_At := Cursor;
                     exit;
                  end if;
               end loop;
            end if;
            if Package_At > 0
              and then Giflib_Tooling.Source_Tokens.Kind_Of (Statement (Package_At + 1)) =
                Giflib_Tooling.Source_Tokens.Identifier
            then
               for Index in Package_At + 2 .. Statement.Last_Index loop
                  Giflib_Tooling.Work_Budgets.Charge (Budget);
                  if Giflib_Tooling.Source_Tokens.Image (Statement (Index)) = "is"
                    and then Index < Statement.Last_Index
                    and then Giflib_Tooling.Source_Tokens.Image (Statement (Index + 1)) = "new"
                  then
                     if Index + 2 <= Statement.Last_Index then
                        for Open in Index + 2 .. Statement.Last_Index loop
                           Giflib_Tooling.Work_Budgets.Charge (Budget);
                           if Giflib_Tooling.Source_Tokens.Image (Statement (Open)) = "(" then
                              declare
                                 Scan_Length : constant Natural :=
                                   Natural
                                     (Open - Statement.First_Index + 1);
                              begin
                                 Giflib_Tooling.Work_Budgets.Charge_Scan
                                   (Budget, Scan_Length);
                                 declare
                                    Generic_Result : constant
                                      Calls.Callee_Result :=
                                        Calls.Callee_Before (Statement, Open);
                                 begin
                                 if Generic_Result.Status /= Calls.Callee_Found
                                 then
                                    Fail
                                      ("cannot resolve ownership generic in " &
                                       Name);
                                 end if;
                                 declare
                                    Generic_Name : constant String :=
                                      Calls.Image (Generic_Result);
                                 begin
                                    if Generic_Name =
                                      "giflib.internal.owned_arrays"
                                      or else Generic_Name =
                                        "giflib.internal.owned_objects"
                                    then
                                       if Scope_At (Positive (Package_At)) /=
                                         Scopes.Package_Unit_Declaration
                                       then
                                          Fail
                                            ("ownership generic must be " &
                                             "declared at package unit level " &
                                             "in " & Name);
                                       end if;
                                       declare
                                          Identity : constant String :=
                                            Name & ":" &
                                            Giflib_Tooling.Source_Tokens.Image
                                              (Statement (Package_At + 1)) &
                                            ":" &
                                            (if Generic_Name =
                                               "giflib.internal.owned_arrays"
                                             then "owned_arrays"
                                             else "owned_objects");
                                       begin
                                          if Found.Contains (Identity) then
                                             Fail
                                               ("duplicate ownership-container " &
                                                "instance: " & Identity);
                                          elsif Natural (Found.Length) >=
                                            Required'Length
                                          then
                                             Fail
                                               ("production ownership-container " &
                                                "instances need safety review");
                                          end if;
                                          Found.Insert (Identity);
                                       end;
                                    elsif Generic_Name in
                                      "owned_arrays" | "owned_objects"
                                    then
                                       Fail
                                         ("ownership generic must be fully " &
                                          "qualified in " & Name);
                                    end if;
                                 end;
                                 end;
                              end;
                              exit;
                           end if;
                        end loop;
                     end if;
                     exit;
                  elsif Giflib_Tooling.Source_Tokens.Image (Statement (Index)) = "renames" then
                     if Index < Statement.Last_Index then
                        for Cursor in Index + 1 .. Statement.Last_Index loop
                           Giflib_Tooling.Work_Budgets.Charge (Budget);
                           if Giflib_Tooling.Source_Tokens.Image (Statement (Cursor)) in
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
         procedure Analyze (Parsed : Source.Parsed_Source) is
         begin
            Scopes.Scan_Declarations
              (Parsed, Budget, Inspect'Access);
         end Analyze;
      begin
         Giflib_Tooling.Repository_Source_Cache.Inspect
           (Cached_Sources, Path, Analyze'Access);
      end Inspect_File;

      procedure Visit (Path : String; Name : String) is
      begin
         if Source_Names.Is_Ada_Source (Name) then
            Inspect_File (Path);
         end if;
      end Visit;
   begin
      Snapshots.Walk (Repository, "src", Visit'Access);
      if Natural (Found.Length) /= Required'Length then
         Fail ("production ownership-container instances need safety review");
      end if;
      for Item of Required loop
         if not Found.Contains (To_String (Item)) then
            Fail ("reviewed ownership instance is missing");
         end if;
      end loop;
   end Validate;
end Giflib_Tooling.Architecture_Ownership;
