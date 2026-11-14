with Giflib_Tooling.Configuration_Entry_Types;

private package Giflib_Tooling.Configuration_Entry_Parsing is
   function Parse (Line : String)
      return Giflib_Tooling.Configuration_Entry_Types.Parsed_Entry;
end Giflib_Tooling.Configuration_Entry_Parsing;
