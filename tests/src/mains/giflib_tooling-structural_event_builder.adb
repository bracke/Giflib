with Ada.Strings.Unbounded;

with Giflib_Tooling.Structural_Construct_Actions;
with Giflib_Tooling.Structural_Event_Output;
with Giflib_Tooling.Structural_Recognition;

package body Giflib_Tooling.Structural_Event_Builder is
   use Ada.Strings.Unbounded;
   package Actions renames Giflib_Tooling.Structural_Construct_Actions;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Output renames Giflib_Tooling.Structural_Event_Output;
   package Recognition renames Giflib_Tooling.Structural_Recognition;
   package Source renames Giflib_Tooling.Source_Tokens;
   package Types renames Giflib_Tooling.Source_Events;
   use type Source.Token_Kind;
   use Types;

   type Builder_State is record
      Recognition_State : Recognition.Stack;
      Type_Name : Ada.Strings.Unbounded.Unbounded_String;
      In_Type_Declaration : Boolean := False;
      Type_Parentheses : Natural := 0;
   end record;

   procedure Process_Token
     (Object : in out Builder_State;
      Tokens : Source.Token_Vectors.Vector;
      Events : in out Structural_Event_Vectors.Vector;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget;
      Index : Positive)
   is
      procedure Track_Type_Declaration is
      begin
         if Source.Image (Tokens (Index)) = "type"
           and then Source.Kind_Of (Tokens (Index + 1)) = Source.Identifier
         then
            Object.Type_Name := Source.Text_Of (Tokens (Index + 1));
            Object.In_Type_Declaration := True;
            Object.Type_Parentheses := 0;
         elsif Object.In_Type_Declaration
           and then Source.Image (Tokens (Index)) = "("
         then
            Object.Type_Parentheses := Object.Type_Parentheses + 1;
         elsif Object.In_Type_Declaration
           and then Source.Image (Tokens (Index)) = ")"
           and then Object.Type_Parentheses > 0
         then
            Object.Type_Parentheses := Object.Type_Parentheses - 1;
         elsif Object.In_Type_Declaration
           and then Object.Type_Parentheses = 0
           and then Source.Image (Tokens (Index)) = ";"
         then
            Object.In_Type_Declaration := False;
            Object.Type_Name := Null_Unbounded_String;
         end if;
      end Track_Type_Declaration;

      procedure Apply (Item : Actions.Action) is
      begin
         case Item.Kind is
            when Actions.No_Action =>
               null;
            when Actions.End_Record =>
               Output.Append_Terminal
                 (Events, Index, Record_End,
                  Limits.Maximum_Structural_Events, Storage);
               Recognition.Close_Record (Object.Recognition_State);
            when Actions.End_Loop =>
               Output.Append_Terminal
                 (Events, Index, Loop_End,
                  Limits.Maximum_Structural_Events, Storage);
            when Actions.End_Return =>
               Output.Append_Terminal
                 (Events, Index, Return_End,
                  Limits.Maximum_Structural_Events, Storage);
            when Actions.End_Control =>
               Output.Append_Terminal
                 (Events, Index, Control_End,
                  Limits.Maximum_Structural_Events, Storage);
            when Actions.End_Scope =>
               Output.Append_Scope_End
                 (Events, Index, Item.Ending_Name,
                  Limits.Maximum_Structural_Events, Storage);
               Recognition.Close
                 (Object.Recognition_State, Item.Ending_Name);
            when Actions.Start_Subprogram =>
               Output.Append_Subprogram
                 (Events, Object.Recognition_State, Index,
                  Item.Subprogram_Name, Item.Header,
                  Limits.Maximum_Structural_Events,
                  Limits.Maximum_Structural_Depth, Storage);
            when Actions.Start_Package =>
               Output.Append_Package
                 (Events, Object.Recognition_State, Index, Item.Package_Name,
                  Item.Introduces_Scope, Item.Is_Body,
                  Limits.Maximum_Structural_Events,
                  Limits.Maximum_Structural_Depth, Storage);
            when Actions.Start_Program =>
               Output.Append_Program
                 (Events, Object.Recognition_State, Index, Item.Program_Name,
                  Limits.Maximum_Structural_Events,
                  Limits.Maximum_Structural_Depth, Storage);
            when Actions.Start_Block =>
               Output.Append_Block
                 (Events, Object.Recognition_State, Index, Item.Block_Name,
                  Item.Body_Started,
                  Limits.Maximum_Structural_Events,
                  Limits.Maximum_Structural_Depth, Storage);
            when Actions.Mark_Body =>
               Recognition.Mark_Body_Started (Object.Recognition_State);
            when Actions.Start_Record =>
               Output.Append_Record
                 (Events, Object.Recognition_State, Index, Item.Record_Name,
                  Limits.Maximum_Structural_Events,
                  Limits.Maximum_Structural_Depth, Storage);
         end case;
      end Apply;
   begin
      Budgets.Charge (Budget);
      Track_Type_Declaration;
      Apply
        (Actions.Recognize
           (Tokens, Index, Recognition.Top (Object.Recognition_State),
            Object.In_Type_Declaration, Object.Type_Name, Budget));
   end Process_Token;

   procedure Build
     (Tokens : Source.Token_Vectors.Vector;
      Events : out Structural_Event_Vectors.Vector;
      Limits : Giflib_Tooling.Source_Limits.Parsing_Limits;
      Budget : in out Budgets.Budget;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget)
   is
      Object : Builder_State;
   begin
      Events.Clear;
      for Index in Tokens.First_Index .. Tokens.Last_Index - 1 loop
         Process_Token
           (Object, Tokens, Events, Limits, Budget, Storage, Index);
      end loop;
   end Build;
end Giflib_Tooling.Structural_Event_Builder;
