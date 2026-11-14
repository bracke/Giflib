with Giflib_Tooling.Model_Storage;
with Giflib_Tooling.Source_Lexing;
with Giflib_Tooling.Source_Statements;
with Giflib_Tooling.Structural_Analysis;

package body Giflib_Tooling.Source_Model is
   package Lexing renames Giflib_Tooling.Source_Lexing;
   package Model_Storage renames Giflib_Tooling.Model_Storage;
   package Limits renames Giflib_Tooling.Source_Limits;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Lex
     (Text : String;
      Constraints : Limits.Parsing_Limits := Limits.Default_Parsing_Limits)
      return Tokens.Token_Vectors.Vector is
     (Lexing.Lex (Text, Constraints));

   function Assemble
     (Items : Tokens.Token_Vectors.Vector;
      Constraints : Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Parsed_Source
   is
      Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Units : Giflib_Tooling.Source_Units.Program_Unit_Vectors.Vector;
      Clause : Giflib_Tooling.Source_Units.Separate_Clause;
   begin
      Giflib_Tooling.Structural_Analysis.Analyze
        (Items, Events, Units, Clause, Constraints, Budget, Storage);
      return
        (Token_Data => Items, Unit_Data => Units, Event_Data => Events,
         Clause_Data => Clause);
   end Assemble;

   function Parse_Core
     (Text : String;
      Position : Natural;
      Complete_Source : Boolean;
      Constraints : Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Parsed_Source
   is
   begin
      Model_Storage.Charge_Model (Storage);
      return Assemble
        ((if Complete_Source
          then Lexing.Lex (Text, Constraints, Storage)
          else Lexing.Lex_Through
            (Text, Position, Constraints, Storage)),
         Constraints, Budget, Storage);
   end Parse_Core;

   function Parse
     (Text : String;
      Constraints : Limits.Parsing_Limits := Limits.Default_Parsing_Limits)
      return Parsed_Source
   is
      Budget : Giflib_Tooling.Work_Budgets.Budget
        (Constraints.Maximum_Structural_Work);
      Storage : Giflib_Tooling.Model_Storage_Budgets.Budget
        (Constraints.Maximum_Model_Storage);
   begin
      return Parse_Core
        (Text, Natural'Last, True, Constraints, Budget, Storage);
   end Parse;

   function Parse
     (Text : String;
      Constraints : Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Parsed_Source
   is
      Storage : Giflib_Tooling.Model_Storage_Budgets.Budget
        (Constraints.Maximum_Model_Storage);
   begin
      return Parse_Core
        (Text, Natural'Last, True, Constraints, Budget, Storage);
   end Parse;

   function Parse
     (Text : String;
      Constraints : Limits.Parsing_Limits;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
      return Parsed_Source
   is
   begin
      return Parse_Core
        (Text, Natural'Last, True, Constraints, Budget, Storage);
   end Parse;

   function Parse_Through
     (Text : String;
      Position : Natural;
      Constraints : Limits.Parsing_Limits := Limits.Default_Parsing_Limits)
      return Parsed_Source
   is
      Budget : Giflib_Tooling.Work_Budgets.Budget
        (Constraints.Maximum_Structural_Work);
      Storage : Giflib_Tooling.Model_Storage_Budgets.Budget
        (Constraints.Maximum_Model_Storage);
   begin
      return Parse_Core
        (Text, Position, False, Constraints, Budget, Storage);
   end Parse_Through;

   procedure Inspect_Tokens
     (Source : Parsed_Source;
      Process : not null access procedure
        (Items : Tokens.Token_Vectors.Vector)) is
   begin
      Process (Source.Token_Data);
   end Inspect_Tokens;

   procedure Inspect_Program_Units
     (Source : Parsed_Source;
      Process : not null access procedure
        (Item : Giflib_Tooling.Source_Units.Program_Unit)) is
   begin
      for Item of Source.Unit_Data loop
         Process (Item);
      end loop;
   end Inspect_Program_Units;

   procedure Inspect_Syntax
     (Source : Parsed_Source;
      Process : not null access procedure
        (Items : Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector)) is
   begin
      Process (Source.Token_Data, Source.Event_Data);
   end Inspect_Syntax;

   function Separate_Clause_Of
     (Source : Parsed_Source)
      return Giflib_Tooling.Source_Units.Separate_Clause is
     (Source.Clause_Data);

   function Storage_Work (Source : Parsed_Source) return Natural is
   begin
      return Natural
        (Long_Long_Integer'Min
           (Long_Long_Integer (Natural'Last),
            1 + Long_Long_Integer (Source.Token_Data.Length)
            + Long_Long_Integer (Source.Unit_Data.Length)
            + Long_Long_Integer (Source.Event_Data.Length)));
   end Storage_Work;

   function Storage_Units (Source : Parsed_Source) return Natural is
     (Model_Storage.Measure
        (Source.Token_Data, Source.Unit_Data, Source.Event_Data,
         Source.Clause_Data));

   function Has_Nested_Program_Unit (Text : String) return Boolean is
      Parsed : constant Parsed_Source := Parse (Text);
      Result : Boolean := False;
      procedure Inspect (Unit_Info : Giflib_Tooling.Source_Units.Program_Unit) is
      begin
         Result := Result or else Unit_Info.Is_Nested;
      end Inspect;
   begin
      Inspect_Program_Units (Parsed, Inspect'Access);
      return Result;
   end Has_Nested_Program_Unit;

   procedure Scan_Statements
     (Source : Parsed_Source;
      Process : not null access procedure
        (Statement : Tokens.Token_Vectors.Vector)) is
   begin
      Giflib_Tooling.Source_Statements.Scan (Source.Token_Data, Process);
   end Scan_Statements;

   procedure Scan_Statements
     (Text : String;
      Process : not null access procedure
        (Statement : Tokens.Token_Vectors.Vector))
   is
      Parsed : constant Parsed_Source := Parse (Text);
   begin
      Scan_Statements (Parsed, Process);
   end Scan_Statements;
end Giflib_Tooling.Source_Model;
