with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Model_Storage_Budgets;
with Giflib_Tooling.Structural_Recognition;
with Giflib_Tooling.Structural_Subprograms;

private package Giflib_Tooling.Structural_Event_Output is
   subtype Terminal_Event_Kind is
     Giflib_Tooling.Source_Events.Structural_Event_Kind range
       Giflib_Tooling.Source_Events.Record_End ..
       Giflib_Tooling.Source_Events.Control_End;
   procedure Append_Terminal
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Index : Positive;
      Kind : Terminal_Event_Kind;
      Maximum_Events : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Scope_End
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Subprogram
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Recognition_State : in out Giflib_Tooling.Structural_Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Info : Giflib_Tooling.Structural_Subprograms.Subprogram_Info;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Package
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Recognition_State : in out Giflib_Tooling.Structural_Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Introduces_Scope : Boolean;
      Is_Body : Boolean;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Program
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Recognition_State : in out Giflib_Tooling.Structural_Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Block
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Recognition_State : in out Giflib_Tooling.Structural_Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Body_Started : Boolean;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
   procedure Append_Record
     (Events : in out
        Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
      Recognition_State : in out Giflib_Tooling.Structural_Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Giflib_Tooling.Model_Storage_Budgets.Budget);
end Giflib_Tooling.Structural_Event_Output;
