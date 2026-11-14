with Ada.Strings.Unbounded;

with Giflib_Tooling.Scope_Stacks;

private package Giflib_Tooling.Structural_Scopes is
   type Scope_Kind is
     (Subprogram_Scope, Package_Scope, Program_Scope, Block_Scope,
      Record_Scope);

   type Scope_Id is new Natural;
   No_Scope_Id : constant Scope_Id := 0;

   package Models is new Giflib_Tooling.Scope_Stacks.Models
     (Kind_Type => Scope_Kind,
      Record_Kind => Record_Scope,
      Metadata_Type => Scope_Id,
      Default_Metadata => No_Scope_Id);

   subtype Scope_Frame is Models.Frame;
   subtype Optional_Scope_Frame is Models.Optional_Frame;
   subtype Scope_Stack is Models.Stack;

   function Depth (Stack : Scope_Stack) return Natural;
   function Top (Stack : Scope_Stack) return Optional_Scope_Frame;
   function Id_Of (Item : Scope_Frame) return Scope_Id;
   procedure Push
     (Stack : in out Scope_Stack;
      Kind : Scope_Kind;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Id : Scope_Id := No_Scope_Id);
   procedure Close
     (Stack : in out Scope_Stack;
      Ending_Name : Ada.Strings.Unbounded.Unbounded_String;
      Result : out Optional_Scope_Frame);
   procedure Close_Record
     (Stack : in out Scope_Stack;
      Result : out Optional_Scope_Frame);
end Giflib_Tooling.Structural_Scopes;
