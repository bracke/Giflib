with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Source_Model is
   type Parsed_Source is private;
   function Lex
     (Text : String;
      Constraints : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
   function Parse
     (Text : String;
      Constraints : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Parsed_Source;
   function Parse
     (Text : String;
      Constraints : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Parsed_Source;
   function Parse
     (Text : String;
      Constraints : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Parsed_Source;
   function Parse_Through
     (Text : String;
      Position : Natural;
      Constraints : Giflib_Tooling.Source_Limits.Parsing_Limits :=
        Giflib_Tooling.Source_Limits.Default_Parsing_Limits)
      return Parsed_Source;
   procedure Inspect_Tokens
     (Source : Parsed_Source;
      Process : not null access procedure
        (Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector));
   procedure Inspect_Program_Units
     (Source : Parsed_Source;
      Process : not null access procedure
        (Item : Giflib_Tooling.Source_Units.Program_Unit));
   procedure Inspect_Syntax
     (Source : Parsed_Source;
      Process : not null access procedure
        (Items : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector));
   function Separate_Clause_Of
     (Source : Parsed_Source) return Giflib_Tooling.Source_Units.Separate_Clause;
   function Storage_Work (Source : Parsed_Source) return Natural;
   function Storage_Units (Source : Parsed_Source) return Natural;
   function Has_Nested_Program_Unit (Text : String) return Boolean;
   procedure Scan_Statements
     (Source : Parsed_Source;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector));
   procedure Scan_Statements
     (Text : String;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector));
private
   type Parsed_Source is record
      Token_Data : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Unit_Data : Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Event_Data : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Clause_Data : Giflib_Tooling.Source_Units.Separate_Clause;
   end record;
end Giflib_Tooling.Source_Model;
