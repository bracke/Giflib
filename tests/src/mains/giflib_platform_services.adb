with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Giflib_Platform_Services is
   function Peak_Memory return Memory_Metric is
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists ("/proc/self/status") then
         return (Available => False);
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/self/status");
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Ada.Strings.Fixed.Index (Line, "VmHWM:") = 1 then
               declare
                  First : Natural := Line'First;
                  Last : Natural;
               begin
                  while First <= Line'Last
                    and then Line (First) not in '0' .. '9'
                  loop
                     First := First + 1;
                  end loop;
                  if First > Line'Last then
                     Ada.Text_IO.Close (File);
                     return (Available => False);
                  end if;
                  Last := First;
                  while Last < Line'Last
                    and then Line (Last + 1) in '0' .. '9'
                  loop
                     Last := Last + 1;
                  end loop;
                  declare
                     Result : constant Natural :=
                       Natural'Value (Line (First .. Last));
                  begin
                     Ada.Text_IO.Close (File);
                     return (Available => True, KiB => Result);
                  end;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return (Available => False);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return (Available => False);
   end Peak_Memory;
end Giflib_Platform_Services;
