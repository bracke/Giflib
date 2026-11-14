with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;

package body Giflib_Tooling.Configuration_Text is
   Config_Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & ASCII.HT & ASCII.CR);

   function Trim (Value : String) return String is
     (Ada.Strings.Fixed.Trim
        (Value, Config_Whitespace, Config_Whitespace));
end Giflib_Tooling.Configuration_Text;
