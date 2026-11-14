with Ada.Strings.Unbounded;

package body Giflib_Tooling.Suite_Flow_State is
   package Classification renames
     Giflib_Tooling.Suite_Flow_Classification;
   package Nesting renames Giflib_Tooling.Structural_Scopes;
   package Reachability renames Giflib_Tooling.Suite_Reachability;
   package Syntax renames Giflib_Tooling.Source_Events;
   use type Classification.Flow_Event_Kind;

   procedure Push_Control
     (Object : in out State;
      Kind : Control_Kind;
      Scope_Depth : Natural := 0) is
   begin
      Object.Controls.Append (Control_Frame'(Kind, Scope_Depth));
      Object.Conditional_Depth := Object.Conditional_Depth + 1;
      if Kind /= Exception_Control then
         Object.Branch_Depth := Object.Branch_Depth + 1;
      end if;
   end Push_Control;

   procedure Close_Control
     (Object : in out State; Kind : Control_Kind) is
   begin
      if not Object.Controls.Is_Empty
        and then Object.Controls.Last_Element.Kind = Kind
      then
         Object.Controls.Delete_Last;
         Object.Conditional_Depth := Object.Conditional_Depth - 1;
         if Kind /= Exception_Control then
            Object.Branch_Depth := Object.Branch_Depth - 1;
         end if;
      end if;
   end Close_Control;

   procedure Observe_Event
     (Object : in out State; Event : Syntax.Structural_Event)
   is
      Closed : Nesting.Optional_Scope_Frame;
      Depth : constant Natural := Nesting.Depth (Object.Structural_Scopes);
   begin
      case Event.Kind is
         when Syntax.Subprogram_Start =>
            if Event.Header.Introduces_Scope then
               Nesting.Push
                 (Object.Structural_Scopes, Nesting.Subprogram_Scope,
                  Event.Subprogram_Name);
            end if;
         when Syntax.Package_Start =>
            if Event.Package_Introduces_Scope then
               Nesting.Push
                 (Object.Structural_Scopes, Nesting.Package_Scope,
                  Event.Package_Name);
            end if;
         when Syntax.Program_Start =>
            Nesting.Push
              (Object.Structural_Scopes, Nesting.Program_Scope,
               Event.Program_Name);
         when Syntax.Block_Start =>
            Nesting.Push
              (Object.Structural_Scopes, Nesting.Block_Scope,
               Event.Block_Name);
         when Syntax.Record_Start =>
            Nesting.Push
              (Object.Structural_Scopes, Nesting.Record_Scope,
               Event.Record_Name);
         when Syntax.Scope_End =>
            if not Object.Controls.Is_Empty
              and then Object.Controls.Last_Element.Kind = Exception_Control
              and then Object.Controls.Last_Element.Scope_Depth = Depth
            then
               Object.Controls.Delete_Last;
               Object.Conditional_Depth := Object.Conditional_Depth - 1;
            end if;
            Reachability.Finish_Scope (Object.Reachability, Depth);
            Nesting.Close
              (Object.Structural_Scopes, Event.Ending_Name, Closed);
         when Syntax.Record_End =>
            Nesting.Close_Record (Object.Structural_Scopes, Closed);
         when others =>
            null;
      end case;
   end Observe_Event;

   procedure Process_Label
     (Object : in out State;
      Event : Classification.Flow_Event) is
   begin
      if Event.Kind = Classification.Label_Reached then
         Reachability.Reach_Label
           (Object.Reachability,
            Ada.Strings.Unbounded.To_String (Event.Name));
      end if;
   end Process_Label;

   procedure Prepare_Token
     (Object : in out State;
      Event : Classification.Flow_Event) is
   begin
      case Event.Kind is
         when Classification.If_Closed =>
            Close_Control (Object, If_Control);
         when Classification.Case_Closed =>
            Close_Control (Object, Case_Control);
         when Classification.Select_Closed =>
            Close_Control (Object, Select_Control);
         when Classification.Loop_Closed =>
            Close_Control (Object, Loop_Control);
         when others =>
            null;
      end case;
   end Prepare_Token;

   procedure Process_Token
     (Object : in out State;
      Event : Classification.Flow_Event) is
   begin
      case Event.Kind is
         when Classification.If_Opened =>
            Push_Control (Object, If_Control);
         when Classification.Case_Opened =>
            Push_Control (Object, Case_Control);
         when Classification.Select_Opened =>
            Push_Control (Object, Select_Control);
         when Classification.Loop_Opened =>
            Push_Control (Object, Loop_Control);
         when Classification.Exception_Started =>
            declare
               Depth : constant Natural :=
                 Nesting.Depth (Object.Structural_Scopes);
            begin
               Push_Control (Object, Exception_Control, Depth);
               Reachability.Start_Exception_Handler
                 (Object.Reachability, Depth);
            end;
         when Classification.Catch_All_Started =>
            Reachability.Catch_All (Object.Reachability);
         when Classification.Return_Statement =>
            if Reachability.Sequentially_Reachable (Object.Reachability) then
               Reachability.Record_Return
                 (Object.Reachability, Object.Branch_Depth);
            end if;
         when Classification.Raise_Statement =>
            if Reachability.Sequentially_Reachable (Object.Reachability) then
               Reachability.Record_Raise
                 (Object.Reachability,
                  Nesting.Depth (Object.Structural_Scopes),
                  Object.Branch_Depth);
            end if;
         when Classification.Goto_Statement =>
            if Reachability.Sequentially_Reachable (Object.Reachability) then
               Reachability.Record_Goto
                 (Object.Reachability,
                  Ada.Strings.Unbounded.To_String (Event.Name),
                  Object.Branch_Depth);
            end if;
         when others =>
            null;
      end case;
   end Process_Token;

   function Is_Unconditionally_Reachable (Object : State) return Boolean is
     (Reachability.Is_Unconditionally_Reachable
        (Object.Reachability, Object.Conditional_Depth));

   function Step
     (Object : in out State;
      Event : Classification.Flow_Event;
      Eligible : Boolean) return Boolean
   is
      Result : Boolean;
   begin
      Process_Label (Object, Event);
      if not Eligible then
         return False;
      end if;
      Prepare_Token (Object, Event);
      Result := Is_Unconditionally_Reachable (Object);
      Process_Token (Object, Event);
      return Result;
   end Step;
end Giflib_Tooling.Suite_Flow_State;
