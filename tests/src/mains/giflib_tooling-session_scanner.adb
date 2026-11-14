with Giflib_Tooling.Session_Semantic_Events;
with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_State.Resolution;
with Giflib_Tooling.Source_Events;

package body Giflib_Tooling.Session_Scanner is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Resolution renames Giflib_Tooling.Session_State.Resolution;
   package Semantic_Events renames
     Giflib_Tooling.Session_Semantic_Events;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Model;
   use Giflib_Tooling.Session_State;
   use Giflib_Tooling.Source_Events;
   use Giflib_Tooling.Name_Collections;
   use Giflib_Tooling.Source_Tokens;
   use Semantics;

   procedure Scan
     (Parsed : Source.Parsed_Source;
      Request : Scan_Request;
      Discovered_Context : in out Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Process : not null access procedure
        (Statement : Token_Vectors.Vector;
         Session_Names : Name_Vectors.Vector))
   is
      procedure Analyze
        (Tokens : Token_Vectors.Vector;
         Events : Structural_Event_Vectors.Vector)
      is
         Analysis_State : State;
         Statement : Token_Vectors.Vector;
         Parenthesis_Depth : Natural := 0;
         Next_Event : Natural :=
           (if Events.Is_Empty then 0 else Events.First_Index);

         function Event_At (Index : Positive) return Structural_Event is
         begin
            if Next_Event > 0
              and then Next_Event <= Events.Last_Index
              and then Events (Next_Event).Token_Index = Index
            then
               return Result : constant Structural_Event :=
                 Events (Next_Event)
               do
                  Next_Event := Next_Event + 1;
               end return;
            end if;
            return (others => <>);
         end Event_At;
      begin
         if Request.Context_Seed = Include_Initial_Context then
            Budgets.Charge_Scan
              (Budget, Natural (Request.Initial_Context.Length));
            Discovered_Context := Request.Initial_Context;
         end if;
         Semantic_Events.Initialize
           (Analysis_State, Request.Target_Type, Budget,
            Request.Initial_Context);
         for Index in Tokens.First_Index .. Tokens.Last_Index loop
            Budgets.Charge (Budget);
            Statement.Append (Tokens (Index));
            if Image (Tokens (Index)) = "(" then
               Parenthesis_Depth := Parenthesis_Depth + 1;
            elsif Image (Tokens (Index)) = ")"
              and then Parenthesis_Depth > 0
            then
               Parenthesis_Depth := Parenthesis_Depth - 1;
            end if;
            Semantic_Events.Apply
              (Tokens, Statement, Index, Event_At (Index), Analysis_State,
               Discovered_Context, Budget,
               Ada.Strings.Unbounded.To_String (Request.Unit_Scope));
            if Image (Tokens (Index)) = ";" then
               if not Statement.Is_Empty then
                  Process
                    (Statement,
                     Resolution.Visible_Sessions (Analysis_State, Budget));
                  Statement.Clear;
               end if;
               Semantic_Events.Finish_Statement
                 (Analysis_State, Parenthesis_Depth, Budget);
            end if;
         end loop;
         if not Statement.Is_Empty then
            Process
              (Statement,
               Resolution.Visible_Sessions (Analysis_State, Budget));
         end if;
      end Analyze;
   begin
      Source.Inspect_Syntax (Parsed, Analyze'Access);
   end Scan;
end Giflib_Tooling.Session_Scanner;

