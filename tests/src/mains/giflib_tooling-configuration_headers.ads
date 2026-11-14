with Ada.Strings.Unbounded;

private package Giflib_Tooling.Configuration_Headers is
   type Header_Kind is (Not_A_Header, Valid_Header, Malformed_Header);
   type Header (Kind : Header_Kind := Not_A_Header) is record
      case Kind is
         when Valid_Header =>
            Name : Ada.Strings.Unbounded.Unbounded_String;
            Is_Array : Boolean;
         when Not_A_Header | Malformed_Header =>
            null;
      end case;
   end record;

   function Parse (Line : String) return Header;
end Giflib_Tooling.Configuration_Headers;
