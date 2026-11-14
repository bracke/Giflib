with Ada.Finalization;
with System;

private with GNAT.OS_Lib;

private package Giflib_Tooling.Repository_Handles is
   type Owner is new Ada.Finalization.Limited_Controlled with private;

   function Open_Read (Object : in out Owner; Path : String) return Boolean;
   procedure Close (Object : in out Owner);
   overriding procedure Finalize (Object : in out Owner);

   function Is_Open (Object : Owner) return Boolean;
   function Descriptor_Path (Object : Owner) return String;
   function Is_Regular_File (Object : Owner) return Boolean;
   function Is_Directory (Object : Owner) return Boolean;
   function Length (Object : Owner) return Long_Integer;
   function Read
     (Object : Owner; Address : System.Address; Length : Natural)
      return Integer;
   procedure Seek_Start (Object : Owner);
private
   type Owner is new Ada.Finalization.Limited_Controlled with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   end record;
end Giflib_Tooling.Repository_Handles;
