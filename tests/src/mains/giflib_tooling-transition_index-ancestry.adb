with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Names;

package body Giflib_Tooling.Transition_Index.Ancestry is
   use Ada.Strings.Unbounded;
   package Names renames Giflib_Tooling.Name_Collections;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Units renames Giflib_Tooling.Source_Units;

   function Stem (Name : String; Suffix : String) return String is
     (Name (Name'First .. Name'Last - Suffix'Length));

   function Nearest_Specification
     (Object : Source_Index; Prefix : String; Target_Stem : String)
      return String
   is
      Candidate : Unbounded_String := To_Unbounded_String (Target_Stem);
      Last_Hyphen : Natural;
   begin
      loop
         if Repositories.Contains
           (Object.Sources, To_String (Candidate) & ".ads")
         then
            return To_String (Candidate) & ".ads";
         end if;
         Last_Hyphen := Ada.Strings.Fixed.Index
           (To_String (Candidate), "-", Going => Ada.Strings.Backward);
         exit when Last_Hyphen = 0
           or else Last_Hyphen <= Target_Stem'First
           or else Last_Hyphen <= Prefix'Length;
         Delete (Candidate, Last_Hyphen, Length (Candidate));
      end loop;
      return "";
   end Nearest_Specification;

   package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type => String,
      Hash => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   procedure Take_Step
     (Object : in out Source_Index;
      Depth : in out Natural) is
   begin
      if Depth >= Object.Maximum_Context_Depth then
         raise Budgets.Work_Limit_Exceeded with
           "context ancestry depth budget exhausted";
      end if;
      Budgets.Charge (Object.Bound.Work.all);
      Depth := Depth + 1;
   end Take_Step;

   function Clause_Of
     (Object : in out Source_Index;
      Name : String)
      return Units.Separate_Clause
   is
      Result : Units.Separate_Clause;
      procedure Capture
        (Ignored_Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Units.Separate_Clause) is
      begin
         pragma Unreferenced (Ignored_Name, Parsed);
         Result := Clause;
         Context_Caches.Remember_Clause
           (Object.Contexts, Object.Bound.Work.all,
            Object.Bound.Storage.all, Name, Clause);
      end Capture;
   begin
      if Context_Caches.Contains_Clause (Object.Contexts, Name) then
         return Context_Caches.Clause_At (Object.Contexts, Name);
      end if;
      Repositories.Inspect
        (Object.Sources, Object.Bound.Cached_Sources.all, Name,
         Object.Bound.Work.all,
         Capture'Access);
      return Result;
   end Clause_Of;

   function Specification_Chain
     (Object : in out Source_Index;
      Prefix : String;
      First_Spec : String;
      Depth : in out Natural) return Names.Name_Vectors.Vector
   is
      Result : Names.Name_Vectors.Vector;
      Current : Unbounded_String := To_Unbounded_String (First_Spec);
   begin
      while Length (Current) > 0 loop
         Take_Step (Object, Depth);
         Result.Append (Current);
         declare
            Name : constant String := To_String (Current);
            Spec_Stem : constant String := Stem (Name, ".ads");
            Last_Hyphen : constant Natural :=
              Ada.Strings.Fixed.Index
                (Spec_Stem, "-", Going => Ada.Strings.Backward);
         begin
            if Last_Hyphen <= Spec_Stem'First
            then
               Current := Null_Unbounded_String;
            else
               Current := To_Unbounded_String
                 (Nearest_Specification
                    (Object, Prefix,
                     Spec_Stem (Spec_Stem'First .. Last_Hyphen - 1)));
            end if;
         end;
      end loop;
      return Result;
   end Specification_Chain;

   procedure Body_Chain
     (Object : in out Source_Index;
      Prefix : String;
      First_Body : String;
      Depth : in out Natural;
      Bodies : out Names.Name_Vectors.Vector;
      Base_Spec : out Unbounded_String)
   is
      Seen : Name_Sets.Set;
      Current : Unbounded_String := To_Unbounded_String (First_Body);
   begin
      Bodies.Clear;
      Base_Spec := Null_Unbounded_String;
      loop
         declare
            Name : constant String := To_String (Current);
         begin
            if Seen.Contains (Name) then
               raise Input_Error with
                 "cyclic separate-subunit context inheritance";
            elsif not Source_Names.In_Family (Name, Prefix) then
               raise Input_Error with
                 "separate-subunit parent is outside transition family: " &
                 Name;
            elsif not Repositories.Contains (Object.Sources, Name) then
               raise Input_Error with "missing separate-subunit parent body";
            end if;
            Take_Step (Object, Depth);
            Seen.Insert (Name);
            Bodies.Append (Current);
            declare
               Clause : constant Units.Separate_Clause :=
                 Clause_Of (Object, Name);
            begin
               case Clause.Kind is
                  when Units.Valid_Separate_Clause =>
                     Current := To_Unbounded_String
                       (Source_Names.Body_File_Name (To_String (Clause.Parent)));
                  when Units.Malformed_Separate_Clause =>
                     raise Input_Error with
                       "malformed separate-subunit declaration: " & Name;
                  when Units.No_Separate_Clause =>
                     Base_Spec := To_Unbounded_String
                       (Nearest_Specification
                          (Object, Prefix, Stem (Name, ".adb")));
                     exit;
               end case;
            end;
         end;
      end loop;
   end Body_Chain;

   function Resolve
     (Object : in out Source_Index;
      Prefix : String;
      Target_Name : String;
      Clause : Units.Separate_Clause) return Names.Name_Vectors.Vector
   is
      Bodies : Names.Name_Vectors.Vector;
      Base_Spec : Unbounded_String;
      Depth : Natural := 0;
   begin
      case Clause.Kind is
         when Units.Malformed_Separate_Clause =>
            raise Input_Error with
              "malformed separate-subunit declaration: " & Target_Name;
         when Units.Valid_Separate_Clause =>
            Body_Chain
              (Object, Prefix,
               Source_Names.Body_File_Name (To_String (Clause.Parent)), Depth,
               Bodies, Base_Spec);
         when Units.No_Separate_Clause =>
            Base_Spec := To_Unbounded_String
              (Nearest_Specification
                 (Object, Prefix, Stem (Target_Name, ".adb")));
      end case;

      declare
         Specifications : constant Names.Name_Vectors.Vector :=
           Specification_Chain
             (Object, Prefix, To_String (Base_Spec), Depth);
         Result : Names.Name_Vectors.Vector;
      begin
         for Index in reverse Specifications.First_Index ..
           Specifications.Last_Index
         loop
            Result.Append (Specifications (Index));
         end loop;
         for Index in reverse Bodies.First_Index .. Bodies.Last_Index loop
            Result.Append (Bodies (Index));
         end loop;
         return Result;
      end;
   end Resolve;
end Giflib_Tooling.Transition_Index.Ancestry;
