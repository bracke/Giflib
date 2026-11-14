with Ada.Text_IO;

with Project_Tools.Text;

package body Giflib_Tooling.Self_Test_Support is
   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Fail ("self-test failed: " & Message);
      end if;
   end Check;

   procedure Skip (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("SKIP giflib tooling: " & Message);
   end Skip;

   function Position_After (Text : String; Fragment : String) return Natural is
     (Project_Tools.Text.Index (Text, Fragment) + Fragment'Length);
end Giflib_Tooling.Self_Test_Support;
