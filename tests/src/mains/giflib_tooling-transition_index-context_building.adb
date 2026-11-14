with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Queries;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Transition_Index.Ancestry;

package body Giflib_Tooling.Transition_Index.Context_Building is
   use Ada.Strings.Unbounded;
   package Names renames Giflib_Tooling.Name_Collections;
   package Source_Names renames Giflib_Tooling.Source_Names;
   package Queries renames Giflib_Tooling.Session_Queries;
   package Units renames Giflib_Tooling.Source_Units;

   procedure Apply_Context
     (Object : in out Source_Index;
      Name : String;
      Target_Type : Identity.Target;
      Context : in out Semantics.Type_Classification_Vectors.Vector)
   is
      procedure Include
        (Unit_Name : String;
         Parsed : Source.Parsed_Source;
         Clause : Units.Separate_Clause) is
      begin
         Context_Caches.Remember_Clause
           (Object.Contexts, Object.Bound.Work.all,
            Object.Bound.Storage.all, Unit_Name, Clause);
         Context := Queries.Package_Type_Context
           (Parsed, Target_Type, Context, Object.Bound.Work.all,
            Source_Names.Unit_Name (Unit_Name));
      end Include;
   begin
      Repositories.Inspect
        (Object.Sources, Object.Bound.Cached_Sources.all, Name,
         Object.Bound.Work.all,
         Include'Access);
   end Apply_Context;

   function Inherited_Context
     (Object : in out Source_Index;
      Prefix : String;
      Target_Type : Identity.Target;
      Target_Name : String;
      Clause : Units.Separate_Clause)
      return Semantics.Type_Classification_Vectors.Vector
   is
      Result : Semantics.Type_Classification_Vectors.Vector;
      Units : constant Names.Name_Vectors.Vector :=
        Ancestry.Resolve (Object, Prefix, Target_Name, Clause);
      Next : Natural := Units.First_Index;
   begin
      declare
         Cached : constant Context_Caches.Context_Lookup :=
           Context_Caches.Load_Deepest_Context
             (Object.Contexts, Object.Bound.Work.all, Prefix,
              Target_Type,
              Units);
      begin
         if Cached.Found then
            Result := Cached.Context;
            Next := Cached.Name_Index + 1;
         end if;
      end;
      if Next <= Natural (Units.Last_Index) then
         for Index in Positive (Next) .. Units.Last_Index loop
            declare
               Name : constant String := To_String (Units (Index));
            begin
               Apply_Context
                 (Object, Name, Target_Type, Result);
               Context_Caches.Remember_Context
                 (Object.Contexts, Object.Bound.Work.all,
                  Object.Bound.Storage.all,
                  Prefix, Target_Type, Name, Result);
            end;
         end loop;
      end if;
      return Result;
   end Inherited_Context;
end Giflib_Tooling.Transition_Index.Context_Building;
