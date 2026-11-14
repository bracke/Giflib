with Ada.Strings.Unbounded;

with Project_Tools.Text;

with Giflib_Tooling.Ada_Context_Clauses;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Architecture_Dependencies is
   use Ada.Strings.Unbounded;
   package Context_Clauses renames Giflib_Tooling.Ada_Context_Clauses;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Syntax renames Giflib_Tooling.Name_Collections;
   package Text_Case renames Giflib_Tooling.Text_Case;

   procedure Require_Only_Allowed_With_Clauses
     (Path : String;
      Units : Syntax.Name_Vectors.Vector;
      Prefix : String;
      Allowed : Project_Tools.Ada_Source.String_List)
   is
      Target : constant String := Text_Case.Lower (Prefix);

      function Starts_With (Value : String; Start : String) return Boolean is
        (Value'Length >= Start'Length
         and then Value (Value'First .. Value'First + Start'Length - 1) = Start);

      function Is_Allowed (Name : String) return Boolean is
      begin
         for Item of Allowed loop
            if Name = Text_Case.Lower (To_String (Item)) then
               return True;
            end if;
         end loop;
         return False;
      end Is_Allowed;
   begin
      for Item of Units loop
         declare
            Name : constant String := Text_Case.Lower (To_String (Item));
         begin
            if Starts_With (Name, Target) and then not Is_Allowed (Name) then
               Fail (Path & " imports disallowed unit " & Name);
            end if;
         end;
      end loop;
   end Require_Only_Allowed_With_Clauses;

   procedure Require_Only_Allowed_With_Clauses
     (Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Path : String;
      Prefix : String;
      Allowed : Project_Tools.Ada_Source.String_List;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
   is
      Units : Syntax.Name_Vectors.Vector;
      procedure Load (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
      begin
         Units := Context_Clauses.Units (Parsed);
      end Load;
   begin
      Giflib_Tooling.Work_Budgets.Charge_Scan
        (Budget,
         Giflib_Tooling.Repository_Source_Cache.Source_Length
           (Cached_Sources, Path));
      Giflib_Tooling.Repository_Source_Cache.Inspect
        (Cached_Sources, Path, Load'Access);
      Require_Only_Allowed_With_Clauses (Path, Units, Prefix, Allowed);
   end Require_Only_Allowed_With_Clauses;

   procedure Validate
     (Repository : Repository_Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Empty : constant Project_Tools.Ada_Source.String_List := [1 .. 0 => <>];
      procedure Inspect (Path : String; Name : String) is
      begin
         if Project_Tools.Text.Starts_With
           (Text_Case.Lower (Name), "giflib-internal-")
           and then Source_Names.Is_Ada_Source (Name)
         then
            declare
               Units : Syntax.Name_Vectors.Vector;
               procedure Load
                 (Parsed : Giflib_Tooling.Source_Model.Parsed_Source) is
               begin
                  Units := Context_Clauses.Units (Parsed);
               end Load;
            begin
               Giflib_Tooling.Work_Budgets.Charge_Scan
                 (Budget,
                  Giflib_Tooling.Repository_Source_Cache.Source_Length
                    (Cached_Sources, Path));
               Giflib_Tooling.Repository_Source_Cache.Inspect
                 (Cached_Sources, Path, Load'Access);
               Require_Only_Allowed_With_Clauses
                 (Path, Units, "Giflib.Decoding", Empty);
               Require_Only_Allowed_With_Clauses
                 (Path, Units, "Giflib.Encoding", Empty);
               Require_Only_Allowed_With_Clauses
                 (Path, Units, "Giflib.Quantization", Empty);
            end;
         end if;
      end Inspect;
   begin
      Repository_Snapshots.Walk (Repository, "src", Inspect'Access);
   end Validate;
end Giflib_Tooling.Architecture_Dependencies;
