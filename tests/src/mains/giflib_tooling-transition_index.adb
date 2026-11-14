with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Transition_Index.Ancestry;
with Giflib_Tooling.Transition_Index.Context_Building;

package body Giflib_Tooling.Transition_Index is
   package Names renames Giflib_Tooling.Source_Names;
   package Units renames Giflib_Tooling.Source_Units;

   procedure Build
     (Object : in out Source_Index;
      Maximum_Context_Depth : Positive := Budgets.Maximum_Depth)
   is
   begin
      Object.Maximum_Context_Depth := Maximum_Context_Depth;
      Repositories.Build
        (Object.Sources, Object.Bound.Repository.all,
         Object.Bound.Cached_Sources.all, Object.Bound.Work.all,
         Object.Bound.Storage.all);
   end Build;

   procedure Inspect_Visible_Sources
     (Object : in out Source_Index;
      Prefix : String;
      Target_Name : String;
      Clause : Units.Separate_Clause;
      Process : not null access procedure
        (Name : String;
         Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
         Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector))
   is
      Visible : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;

      procedure Inspect (Name : String) is
         procedure Deliver
           (Type_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
            Callable_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
         is
         begin
            Process (Name, Type_Names, Callable_Names);
         end Deliver;
      begin
         Repositories.Visit_Declarations
           (Object.Sources, Name, Deliver'Access);
      end Inspect;
   begin
      Visible := Giflib_Tooling.Transition_Index.Ancestry.Resolve
        (Object, Prefix, Target_Name, Clause);
      for Name of Visible loop
         Inspect (Giflib_Tooling.Name_Collections.Value (Name));
      end loop;
      Inspect (Target_Name);
   end Inspect_Visible_Sources;

   procedure Scan_Family
     (Object : in out Source_Index;
      Prefix : String;
      Owner : String;
      Target_Type : Identity.Target;
      Process : not null access procedure
        (Name : String;
         Parsed : Source.Parsed_Source;
         Context : Semantics.Type_Classification_Vectors.Vector))
   is
   begin
      for Index in 1 .. Repositories.Count (Object.Sources) loop
         declare
            Name : constant String :=
              Repositories.Name_At (Object.Sources, Index);
         begin
            if Names.In_Family (Name, Prefix)
              and then Name'Length >= 4
              and then Name (Name'Last - 3 .. Name'Last) = ".adb"
              and then Name /= Owner
            then
               declare
                  procedure Deliver
                    (Ignored_Name : String;
                     Parsed : Source.Parsed_Source;
                     Clause : Units.Separate_Clause)
                  is
                     pragma Unreferenced (Ignored_Name);
                  begin
                     Context_Caches.Remember_Clause
                       (Object.Contexts, Object.Bound.Work.all,
                        Object.Bound.Storage.all, Name, Clause);
                     declare
                        Context : constant
                          Semantics.Type_Classification_Vectors.Vector :=
                            Giflib_Tooling.Transition_Index.Context_Building
                              .Inherited_Context
                              (Object, Prefix, Target_Type, Name, Clause);
                     begin
                        Process (Name, Parsed, Context);
                     end;
                  end Deliver;
               begin
                  Repositories.Inspect
                    (Object.Sources, Object.Bound.Cached_Sources.all, Index,
                     Object.Bound.Work.all,
                     Deliver'Access);
               end;
            end if;
         end;
      end loop;
   end Scan_Family;
end Giflib_Tooling.Transition_Index;
