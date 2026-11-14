private with Ada.Containers.Vectors;

with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Suite_Flow_Classification;
private with Giflib_Tooling.Structural_Scopes;
private with Giflib_Tooling.Suite_Reachability;

private package Giflib_Tooling.Suite_Flow_State is
   type State is private;
   procedure Observe_Event
     (Object : in out State;
      Event : Giflib_Tooling.Source_Events.Structural_Event);
   function Step
     (Object : in out State;
      Event : Giflib_Tooling.Suite_Flow_Classification.Flow_Event;
      Eligible : Boolean) return Boolean;
private
   type Control_Kind is
     (If_Control, Case_Control, Select_Control, Loop_Control,
      Exception_Control);
   type Control_Frame is record
      Kind : Control_Kind;
      Scope_Depth : Natural := 0;
   end record;
   package Control_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Control_Frame);
   type State is record
      Controls : Control_Vectors.Vector;
      Structural_Scopes : Giflib_Tooling.Structural_Scopes.Scope_Stack;
      Conditional_Depth : Natural := 0;
      Branch_Depth : Natural := 0;
      Reachability : Giflib_Tooling.Suite_Reachability.State;
   end record;
end Giflib_Tooling.Suite_Flow_State;
