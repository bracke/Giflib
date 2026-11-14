with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Structural_Recognition;
with Giflib_Tooling.Structural_Subprograms;
with Giflib_Tooling.Work_Budgets;

private package Giflib_Tooling.Structural_Construct_Actions is
   type Action_Kind is
     (No_Action,
      End_Record,
      End_Loop,
      End_Return,
      End_Control,
      End_Scope,
      Start_Subprogram,
      Start_Package,
      Start_Program,
      Start_Block,
      Mark_Body,
      Start_Record);

   type Action (Kind : Action_Kind := No_Action) is record
      case Kind is
         when End_Scope =>
            Ending_Name : Ada.Strings.Unbounded.Unbounded_String;
         when Start_Subprogram =>
            Subprogram_Name : Ada.Strings.Unbounded.Unbounded_String;
            Header : Giflib_Tooling.Structural_Subprograms.Subprogram_Info;
         when Start_Package =>
            Package_Name : Ada.Strings.Unbounded.Unbounded_String;
            Introduces_Scope : Boolean;
            Is_Body : Boolean;
         when Start_Program =>
            Program_Name : Ada.Strings.Unbounded.Unbounded_String;
         when Start_Block =>
            Block_Name : Ada.Strings.Unbounded.Unbounded_String;
            Body_Started : Boolean;
         when Start_Record =>
            Record_Name : Ada.Strings.Unbounded.Unbounded_String;
         when No_Action | End_Record | End_Loop | End_Return | End_Control |
           Mark_Body =>
            null;
      end case;
   end record;

   function Recognize
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Index : Positive;
      Top : Giflib_Tooling.Structural_Recognition.Top_State;
      In_Type_Declaration : Boolean;
      Type_Name : Ada.Strings.Unbounded.Unbounded_String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Action;
end Giflib_Tooling.Structural_Construct_Actions;
