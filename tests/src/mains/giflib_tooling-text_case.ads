with Ada.Characters.Handling;

private package Giflib_Tooling.Text_Case is
   function Lower (Value : String) return String
      renames Ada.Characters.Handling.To_Lower;
end Giflib_Tooling.Text_Case;
