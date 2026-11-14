with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Declaration_Analysis is
   package Source renames Giflib_Tooling.Source_Tokens;

   procedure Inspect_Record_At
     (Tokens : Source.Token_Vectors.Vector;
      Record_Index : Positive;
      Process : not null access procedure
        (Name : Ada.Strings.Unbounded.Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive));
   procedure Inspect_Record
     (Tokens : Source.Token_Vectors.Vector;
      Type_Name : String;
      Process : not null access procedure
        (Name : Ada.Strings.Unbounded.Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive));
end Giflib_Tooling.Declaration_Analysis;
