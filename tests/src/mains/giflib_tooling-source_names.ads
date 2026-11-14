private package Giflib_Tooling.Source_Names is
   function Is_Ada_Source (File_Name : String) return Boolean;
   function Specification_File_Name (Unit_Name : String) return String;
   function Body_File_Name (Unit_Name : String) return String;
   function Unit_Name (File_Name : String) return String;
   function In_Family (File_Name : String; Prefix : String) return Boolean;
end Giflib_Tooling.Source_Names;
