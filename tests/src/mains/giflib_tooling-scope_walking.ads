with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Structural_Scopes;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Scope_Walking is
   package Nesting renames Giflib_Tooling.Structural_Scopes;

   procedure Walk
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Before_Event : access procedure
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Event : Giflib_Tooling.Source_Events.Structural_Event;
         Scopes : Nesting.Scope_Stack;
         Subprogram_Id : out Nesting.Scope_Id) := null;
      After_Event : access procedure
        (Event : Giflib_Tooling.Source_Events.Structural_Event;
         Closed : Nesting.Optional_Scope_Frame) := null;
      Visit_Token : access procedure
        (Token : Giflib_Tooling.Source_Tokens.Token;
         Index : Positive;
         Scopes : Nesting.Scope_Stack) := null);
end Giflib_Tooling.Scope_Walking;
