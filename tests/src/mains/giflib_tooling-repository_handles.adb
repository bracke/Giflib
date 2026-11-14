with Ada.Directories;

package body Giflib_Tooling.Repository_Handles is
   use type GNAT.OS_Lib.File_Descriptor;

   function Open_Read (Object : in out Owner; Path : String) return Boolean is
   begin
      Close (Object);
      Object.Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
      return Is_Open (Object);
   end Open_Read;

   procedure Close (Object : in out Owner) is
   begin
      if Object.Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Object.Descriptor);
         Object.Descriptor := GNAT.OS_Lib.Invalid_FD;
      end if;
   end Close;

   overriding procedure Finalize (Object : in out Owner) is
   begin
      Close (Object);
   end Finalize;

   function Is_Open (Object : Owner) return Boolean is
     (Object.Descriptor /= GNAT.OS_Lib.Invalid_FD);

   function Descriptor_Path (Object : Owner) return String is
      Image : constant String := Integer'Image (Integer (Object.Descriptor));
      Number : constant String := Image (Image'First + 1 .. Image'Last);
      Proc_Path : constant String := "/proc/self/fd/" & Number;
      Device_Path : constant String := "/dev/fd/" & Number;
   begin
      if not Is_Open (Object) then
         return "";
      elsif Ada.Directories.Exists (Proc_Path) then
         return Proc_Path;
      elsif Ada.Directories.Exists (Device_Path) then
         return Device_Path;
      end if;
      return "";
   end Descriptor_Path;

   function Is_Regular_File (Object : Owner) return Boolean is
     (Is_Open (Object)
      and then GNAT.OS_Lib.Is_Regular_File (Descriptor_Path (Object)));

   function Is_Directory (Object : Owner) return Boolean is
     (Is_Open (Object)
      and then GNAT.OS_Lib.Is_Directory (Descriptor_Path (Object)));

   function Length (Object : Owner) return Long_Integer is
     (GNAT.OS_Lib.File_Length (Object.Descriptor));

   function Read
     (Object : Owner; Address : System.Address; Length : Natural)
      return Integer
   is (GNAT.OS_Lib.Read (Object.Descriptor, Address, Length));

   procedure Seek_Start (Object : Owner) is
   begin
      GNAT.OS_Lib.Lseek
        (Object.Descriptor, 0, GNAT.OS_Lib.Seek_Set);
   end Seek_Start;
end Giflib_Tooling.Repository_Handles;
