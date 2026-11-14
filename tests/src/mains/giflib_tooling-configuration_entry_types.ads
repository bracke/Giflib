with Ada.Strings.Unbounded;

private package Giflib_Tooling.Configuration_Entry_Types is
   type Entry_Kind is
     (Other_Entry, Header_Entry, Assignment_Entry,
      Malformed_Header_Entry, Malformed_Assignment_Entry);
   type Parsed_Entry (Kind : Entry_Kind := Other_Entry) is record
      case Kind is
         when Header_Entry =>
            Section_Name : Ada.Strings.Unbounded.Unbounded_String;
            Is_Array_Section : Boolean;
         when Assignment_Entry =>
            Key : Ada.Strings.Unbounded.Unbounded_String;
            Value : Ada.Strings.Unbounded.Unbounded_String;
         when Other_Entry | Malformed_Header_Entry |
              Malformed_Assignment_Entry =>
            null;
      end case;
   end record;
end Giflib_Tooling.Configuration_Entry_Types;
