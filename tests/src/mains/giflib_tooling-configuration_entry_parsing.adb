with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Headers;
with Giflib_Tooling.Configuration_Text;

package body Giflib_Tooling.Configuration_Entry_Parsing is
   package Headers renames Giflib_Tooling.Configuration_Headers;
   package Text_Values renames Giflib_Tooling.Configuration_Text;
   package Types renames Giflib_Tooling.Configuration_Entry_Types;
   use type Headers.Header_Kind;

   function Parse (Line : String) return Types.Parsed_Entry is
      Header : constant Headers.Header := Headers.Parse (Line);
      Equal : constant Natural := Ada.Strings.Fixed.Index (Line, "=");

      function Assignment return Types.Parsed_Entry is
        (Kind => Types.Assignment_Entry,
         Key => Ada.Strings.Unbounded.To_Unbounded_String
           (Text_Values.Trim (Line (Line'First .. Equal - 1))),
         Value => Ada.Strings.Unbounded.To_Unbounded_String
           (Text_Values.Trim (Line (Equal + 1 .. Line'Last))));
   begin
      if Equal > 0
        and then (Line'Length = 0 or else Line (Line'First) /= '[')
      then
         return Assignment;
      end if;
      case Header.Kind is
         when Headers.Valid_Header =>
            return
              (Kind => Types.Header_Entry,
               Section_Name => Header.Name,
               Is_Array_Section => Header.Is_Array);
         when Headers.Malformed_Header =>
            return (Kind => Types.Malformed_Header_Entry);
         when Headers.Not_A_Header =>
            if Equal = 0 then
               return (Kind => Types.Other_Entry);
            end if;
            return Assignment;
      end case;
   end Parse;
end Giflib_Tooling.Configuration_Entry_Parsing;
