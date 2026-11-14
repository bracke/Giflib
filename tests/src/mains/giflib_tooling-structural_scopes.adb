package body Giflib_Tooling.Structural_Scopes is
   function Depth (Stack : Scope_Stack) return Natural is
     (Models.Depth (Stack));

   function Top (Stack : Scope_Stack) return Optional_Scope_Frame is
     (Models.Top (Stack));

   function Id_Of (Item : Scope_Frame) return Scope_Id is
     (Item.Metadata);

   procedure Push
     (Stack : in out Scope_Stack;
      Kind : Scope_Kind;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Id : Scope_Id := No_Scope_Id) is
   begin
      Models.Push (Stack, Kind, Name, Metadata => Id);
   end Push;

   procedure Close
     (Stack : in out Scope_Stack;
      Ending_Name : Ada.Strings.Unbounded.Unbounded_String;
      Result : out Optional_Scope_Frame) is
   begin
      Models.Close (Stack, Ending_Name, Result);
   end Close;

   procedure Close_Record
     (Stack : in out Scope_Stack;
      Result : out Optional_Scope_Frame) is
   begin
      Models.Close_Record (Stack, Result);
   end Close_Record;
end Giflib_Tooling.Structural_Scopes;
