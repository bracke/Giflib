with Ada.Containers.Vectors;

with Giflib_Tooling.Name_Collections;

private package Giflib_Tooling.Suite_Reachability is
   type State is private;

   function Sequentially_Reachable (Object : State) return Boolean;
   function Is_Unconditionally_Reachable
     (Object : State; Conditional_Depth : Natural) return Boolean;

   procedure Reach_Label (Object : in out State; Name : String);
   procedure Record_Return
     (Object : in out State; Conditional_Depth : Natural);
   procedure Record_Raise
     (Object : in out State;
      Scope_Depth : Natural;
      Conditional_Depth : Natural);
   procedure Record_Goto
     (Object : in out State;
      Name : String;
      Conditional_Depth : Natural);
   procedure Start_Exception_Handler
     (Object : in out State; Scope_Depth : Natural);
   procedure Catch_All (Object : in out State);
   procedure Finish_Scope
     (Object : in out State; Scope_Depth : Natural);
private
   type Raise_Id is new Natural;
   No_Raise_Id : constant Raise_Id := 0;
   type Raise_Event is record
      Id : Raise_Id := No_Raise_Id;
      Scope_Depth : Natural := 0;
      Blocks_Fallthrough : Boolean := False;
   end record;
   package Raise_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Raise_Event);

   type Handler_Frame is record
      Scope_Depth : Natural := 0;
      Entry_Last_Raise : Raise_Id := No_Raise_Id;
      Catches_All : Boolean := False;
      Normal_Fallthrough : Boolean := False;
   end record;
   package Handler_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Handler_Frame);

   type State is record
      Permanent_Escape : Boolean := False;
      Next_Raise_Id : Raise_Id := No_Raise_Id;
      Raises : Raise_Vectors.Vector;
      Handlers : Handler_Vectors.Vector;
      Goto_Targets : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Sequential_Reachable : Boolean := True;
   end record;
end Giflib_Tooling.Suite_Reachability;
