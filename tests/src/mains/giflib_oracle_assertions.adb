with Giflib;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

package body Giflib_Oracle_Assertions is
   use type Giflib.Byte;

   procedure Require (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Project_Tools.Release_Checks.Fail
           ("giflib_external_checks: " & Message);
      end if;
   end Require;

   procedure Exact_RGBA
     (Path : String; Expected : Giflib.Streams.Byte_Array;
      Description : String)
   is
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
   begin
      Require (Raw'Length = Expected'Length, Description & " byte count changed");
      for I in Expected'Range loop
         Require
           (Giflib.Byte (Character'Pos (Raw (Raw'First + I - Expected'First))) =
              Expected (I),
            Description & " pixel mismatch at byte" &
              Natural'Image (I - Expected'First));
      end loop;
   end Exact_RGBA;

end Giflib_Oracle_Assertions;
