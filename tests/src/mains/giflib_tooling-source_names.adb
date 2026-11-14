with Project_Tools.Text;

with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Source_Names is
   package Text_Case renames Giflib_Tooling.Text_Case;

   function Is_Ada_Source (File_Name : String) return Boolean is
      Normalized : constant String := Text_Case.Lower (File_Name);
   begin
      return Project_Tools.Text.Ends_With (Normalized, ".ads")
        or else Project_Tools.Text.Ends_With (Normalized, ".adb");
   end Is_Ada_Source;

   function File_Name (Unit_Name : String; Suffix : String) return String is
      Result : String := Text_Case.Lower (Unit_Name);
   begin
      for Character of Result loop
         if Character = '.' then
            Character := '-';
         end if;
      end loop;
      return Result & Suffix;
   end File_Name;

   function Specification_File_Name (Unit_Name : String) return String is
     (File_Name (Unit_Name, ".ads"));

   function Body_File_Name (Unit_Name : String) return String is
     (File_Name (Unit_Name, ".adb"));

   function Unit_Name (File_Name : String) return String is
      Suffix_Length : constant Natural :=
        (if File_Name'Length > 4 and then Is_Ada_Source (File_Name)
         then 4 else 0);
      Result : String :=
        File_Name
          (File_Name'First .. File_Name'Last - Suffix_Length);
   begin
      for Character of Result loop
         if Character = '-' then
            Character := '.';
         end if;
      end loop;
      return Text_Case.Lower (Result);
   end Unit_Name;

   function In_Family (File_Name : String; Prefix : String) return Boolean is
     (Project_Tools.Text.Starts_With (File_Name, Prefix)
      and then File_Name'Length > Prefix'Length
      and then File_Name (File_Name'First + Prefix'Length) in '-' | '.');

end Giflib_Tooling.Source_Names;
