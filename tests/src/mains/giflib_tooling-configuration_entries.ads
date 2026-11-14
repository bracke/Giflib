with Giflib_Tooling.Configuration_Entry_Types;

private package Giflib_Tooling.Configuration_Entries is
   package Types renames Giflib_Tooling.Configuration_Entry_Types;
   subtype Entry_Kind is Types.Entry_Kind;
   Other_Entry : constant Entry_Kind := Types.Other_Entry;
   Header_Entry : constant Entry_Kind := Types.Header_Entry;
   Assignment_Entry : constant Entry_Kind := Types.Assignment_Entry;
   Malformed_Header_Entry : constant Entry_Kind :=
     Types.Malformed_Header_Entry;
   Malformed_Assignment_Entry : constant Entry_Kind :=
     Types.Malformed_Assignment_Entry;
   subtype Parsed_Entry is Types.Parsed_Entry;

   procedure Scan
     (Text : String;
      Process : not null access procedure
        (Item : Parsed_Entry; Stop : in out Boolean));
end Giflib_Tooling.Configuration_Entries;
