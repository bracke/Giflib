with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Suite_Flow_Classification is
   type Flow_Event_Kind is
     (No_Flow_Event, Label_Reached,
      If_Closed, Case_Closed, Select_Closed, Loop_Closed,
      If_Opened, Case_Opened, Select_Opened, Loop_Opened,
      Exception_Started, Catch_All_Started,
      Return_Statement, Raise_Statement, Goto_Statement);
   type Flow_Event is record
      Kind : Flow_Event_Kind := No_Flow_Event;
      Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   function Classify
     (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Index : Positive) return Flow_Event;
end Giflib_Tooling.Suite_Flow_Classification;
