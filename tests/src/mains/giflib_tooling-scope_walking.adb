package body Giflib_Tooling.Scope_Walking is
   package Events renames Giflib_Tooling.Source_Events;
   package Source renames Giflib_Tooling.Source_Model;

   procedure Apply_Event
     (Scopes : in out Nesting.Scope_Stack;
      Event : Events.Structural_Event;
      Subprogram_Id : Nesting.Scope_Id;
      Closed : out Nesting.Optional_Scope_Frame) is
   begin
      Closed := (Present => False);
      case Event.Kind is
         when Events.Subprogram_Start =>
            if Event.Header.Introduces_Scope then
               Nesting.Push
                 (Scopes, Nesting.Subprogram_Scope, Event.Subprogram_Name,
                  Subprogram_Id);
            end if;
         when Events.Package_Start =>
            if Event.Package_Introduces_Scope then
               Nesting.Push
                 (Scopes, Nesting.Package_Scope, Event.Package_Name);
            end if;
         when Events.Program_Start =>
            Nesting.Push (Scopes, Nesting.Program_Scope, Event.Program_Name);
         when Events.Block_Start =>
            Nesting.Push (Scopes, Nesting.Block_Scope, Event.Block_Name);
         when Events.Record_Start =>
            Nesting.Push (Scopes, Nesting.Record_Scope, Event.Record_Name);
         when Events.Scope_End =>
            Nesting.Close (Scopes, Event.Ending_Name, Closed);
         when Events.Record_End =>
            Nesting.Close_Record (Scopes, Closed);
         when Events.No_Structural_Event | Events.Loop_End |
              Events.Return_End | Events.Control_End =>
            null;
      end case;
   end Apply_Event;

   procedure Walk
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Before_Event : access procedure
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Event : Events.Structural_Event;
         Scopes : Nesting.Scope_Stack;
         Subprogram_Id : out Nesting.Scope_Id) := null;
      After_Event : access procedure
        (Event : Events.Structural_Event;
         Closed : Nesting.Optional_Scope_Frame) := null;
      Visit_Token : access procedure
        (Token : Giflib_Tooling.Source_Tokens.Token;
         Index : Positive;
         Scopes : Nesting.Scope_Stack) := null)
   is
      Scopes : Nesting.Scope_Stack;

      procedure Inspect
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Items : Events.Structural_Event_Vectors.Vector)
      is
         Event_Index : Natural :=
           (if Items.Is_Empty then 0 else Items.First_Index);
      begin
         if Tokens.Is_Empty then
            return;
         end if;
         for Index in Tokens.First_Index .. Tokens.Last_Index loop
            while Event_Index /= 0
              and then Items (Positive (Event_Index)).Token_Index = Index
            loop
               Giflib_Tooling.Work_Budgets.Charge (Budget);
               declare
                  Event : Events.Structural_Event renames
                    Items (Positive (Event_Index));
                  Id : Nesting.Scope_Id := Nesting.No_Scope_Id;
                  Closed : Nesting.Optional_Scope_Frame;
               begin
                  if Before_Event /= null then
                     Before_Event (Tokens, Event, Scopes, Id);
                  end if;
                  Apply_Event (Scopes, Event, Id, Closed);
                  if After_Event /= null then
                     After_Event (Event, Closed);
                  end if;
               end;
               if Event_Index = Items.Last_Index then
                  Event_Index := 0;
               else
                  Event_Index := Event_Index + 1;
               end if;
            end loop;
            Giflib_Tooling.Work_Budgets.Charge (Budget);
            if Visit_Token /= null then
               Visit_Token (Tokens (Index), Index, Scopes);
            end if;
         end loop;
      end Inspect;
   begin
      Source.Inspect_Syntax (Parsed, Inspect'Access);
   end Walk;
end Giflib_Tooling.Scope_Walking;
