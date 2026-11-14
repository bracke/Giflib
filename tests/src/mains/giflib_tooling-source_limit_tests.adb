with Giflib_Tooling.Source_Limits;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Source_Units;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Queries;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Source_Limit_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Source renames Giflib_Tooling.Source_Model;
   package Queries renames Giflib_Tooling.Source_Queries;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Run is
      Source_Limit_Rejected : Boolean := False;
      Token_Limit_Rejected : Boolean := False;
      Event_Limit_Rejected : Boolean := False;
      Unit_Limit_Rejected : Boolean := False;
      Structural_Work_Limit_Rejected : Boolean := False;
      Structural_Depth_Limit_Rejected : Boolean := False;
      Mismatched_End_Rejected : Boolean := False;
      Selected_Name_Work_Limit_Rejected : Boolean := False;
      Separate_Work_Limit_Rejected : Boolean := False;
      Aggregate_Work_Limit_Rejected : Boolean := False;
      Model_Storage_Limit_Rejected : Boolean := False;
      Storage_Accounting_Matches : Boolean := False;

      procedure Expect_Parse_Failure
        (Text : String;
         Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
         Rejected : out Boolean) is
      begin
         Rejected := False;
         declare
            Ignored : constant Source.Parsed_Source :=
              Source.Parse (Text, Limits);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Input_Error => Rejected := True;
      end Expect_Parse_Failure;

      procedure Expect_Work_Limit
        (Text : String;
         Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
         Rejected : out Boolean) is
      begin
         Rejected := False;
         declare
            Ignored : constant Source.Parsed_Source :=
              Source.Parse (Text, Limits);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Budgets.Work_Limit_Exceeded => Rejected := True;
      end Expect_Work_Limit;

      procedure Check_Storage_Accounting (Text : String) is
         Work : Budgets.Budget (Natural'Last);
         Storage : Giflib_Tooling.Model_Storage_Budgets.Budget (Natural'Last);
         Parsed : constant Source.Parsed_Source :=
           Source.Parse
             (Text, Giflib_Tooling.Source_Limits.Default_Parsing_Limits,
              Work, Storage);
      begin
         Storage_Accounting_Matches :=
           Storage_Accounting_Matches
           and then Source.Storage_Units (Parsed) =
             Giflib_Tooling.Model_Storage_Budgets.Used (Storage);
         declare
            Required : constant Natural :=
              Giflib_Tooling.Model_Storage_Budgets.Used (Storage);
         begin
            for Limit in 0 .. Required - 1 loop
               declare
                  Cutoff_Work : Budgets.Budget (Natural'Last);
                  Cutoff_Storage :
                    Giflib_Tooling.Model_Storage_Budgets.Budget (Limit);
                  Rejected : Boolean := False;
               begin
                  begin
                     declare
                        Ignored : constant Source.Parsed_Source :=
                          Source.Parse
                            (Text,
                             Giflib_Tooling.Source_Limits
                               .Default_Parsing_Limits,
                             Cutoff_Work, Cutoff_Storage);
                        pragma Unreferenced (Ignored);
                     begin
                        null;
                     end;
                  exception
                     when Giflib_Tooling.Model_Storage_Budgets.Limit_Exceeded =>
                        Rejected := True;
                  end;
                  Storage_Accounting_Matches :=
                    Storage_Accounting_Matches and then Rejected;
               end;
            end loop;
         end;
      end Check_Storage_Accounting;
   begin
      Storage_Accounting_Matches := True;
      Expect_Parse_Failure
        ("abcd",
         (Maximum_Source_Length => 3, others => <>),
         Source_Limit_Rejected);
      Expect_Parse_Failure
        ("a b",
         (Maximum_Tokens => 1, others => <>),
         Token_Limit_Rejected);
      Expect_Parse_Failure
        ("package P is end P;",
         (Maximum_Structural_Events => 0, others => <>),
         Event_Limit_Rejected);
      Expect_Parse_Failure
        ("procedure P;",
         (Maximum_Program_Units => 0, others => <>),
         Unit_Limit_Rejected);
      Expect_Work_Limit
        ("package P is end P;",
         (Maximum_Structural_Work => 1, others => <>),
         Structural_Work_Limit_Rejected);
      begin
         declare
            Ignored : constant Source.Parsed_Source :=
              Source.Parse
                ("package P is end P;",
                 (Maximum_Model_Storage => 3, others => <>));
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Giflib_Tooling.Model_Storage_Budgets.Limit_Exceeded =>
            Model_Storage_Limit_Rejected := True;
      end;
      Expect_Work_Limit
        ("package A.B.C;",
         (Maximum_Structural_Work => 14, others => <>),
         Selected_Name_Work_Limit_Rejected);
      Expect_Parse_Failure
        ("procedure P is begin declare begin null; end; end P;",
         (Maximum_Structural_Depth => 1, others => <>),
         Structural_Depth_Limit_Rejected);
      Expect_Parse_Failure
        ("procedure P is begin null; end Wrong;",
         Giflib_Tooling.Source_Limits.Default_Parsing_Limits,
         Mismatched_End_Rejected);
      declare
         Budget : Budgets.Budget (0);
         Tokens : constant Giflib_Tooling.Source_Tokens.Token_Vectors.Vector :=
           Source.Lex
             ("separate (Giflib.Decoding) procedure Probe is " &
              "begin null; end Probe;");
      begin
         begin
            declare
               Ignored : constant Giflib_Tooling.Source_Units.Separate_Clause :=
                 Queries.Separate_Clause_Of (Tokens, Budget);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Budgets.Work_Limit_Exceeded =>
               Separate_Work_Limit_Rejected := True;
         end;
      end;
      Check_Storage_Accounting
        ("package P is procedure A (X : String; Y : String); " &
         "procedure B (X : String; Y : String); end P;");
      Check_Storage_Accounting
        ("task body Worker is begin null; end Worker;");
      Check_Storage_Accounting
        ("procedure P is type R is record X : Integer; end record; " &
         "begin declare begin null; end; end P;");
      Check_Storage_Accounting
        ("separate (Giflib.Decoding) procedure Probe is begin null; " &
         "end Probe;");
      declare
         Budget : Budgets.Budget (1);
      begin
         begin
            declare
               Ignored : constant Source.Parsed_Source := Source.Parse
                 ("package P is procedure A; end P;",
                  Giflib_Tooling.Source_Limits.Default_Parsing_Limits,
                  Budget);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Budgets.Work_Limit_Exceeded =>
               Aggregate_Work_Limit_Rejected := True;
         end;
      end;
      Check.Check
        (Source_Limit_Rejected and then Token_Limit_Rejected
         and then Event_Limit_Rejected and then Unit_Limit_Rejected
         and then Model_Storage_Limit_Rejected
         and then Structural_Work_Limit_Rejected
         and then Selected_Name_Work_Limit_Rejected
         and then Structural_Depth_Limit_Rejected
         and then Mismatched_End_Rejected
         and then Separate_Work_Limit_Rejected
         and then Aggregate_Work_Limit_Rejected
         and then Storage_Accounting_Matches,
         "source analysis enforces all configured resource limits");
   end Run;
end Giflib_Tooling.Source_Limit_Tests;
