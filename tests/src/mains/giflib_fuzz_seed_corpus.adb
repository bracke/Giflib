with Giflib;
with Project_Tools.Files;

package body Giflib_Fuzz_Seed_Corpus is
   function Literal return Giflib.Streams.Byte_Array is
     ([71, 73, 70, 56, 57, 97, 2, 0, 1, 0, 16#80#, 0, 0,
       0, 0, 0, 255, 255, 255, 16#21#, 16#F9#, 4, 1, 0, 0, 0, 0,
       16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0, 2, 2, 16#44#, 16#0A#, 0,
       16#3B#]);

   function Load
     (Root : String; Relative_Path : String) return Giflib.Streams.Byte_Array
   is
      Raw : constant String := Project_Tools.Files.Read_Raw_File
        (Project_Tools.Files.Join (Root, Relative_Path));
      Result : Giflib.Streams.Byte_Array (1 .. Raw'Length);
   begin
      for I in Raw'Range loop
         Result (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
      end loop;
      return Result;
   end Load;
end Giflib_Fuzz_Seed_Corpus;
