with Ada.Strings.Unbounded;

with Giflib_Tooling.Scope_Stacks;
with Giflib_Tooling.Structural_Scopes;

private package Giflib_Tooling.Structural_Recognition is
   package Scopes renames Giflib_Tooling.Structural_Scopes;
   package Recognition_Stacks is new Giflib_Tooling.Scope_Stacks.Models
     (Kind_Type => Scopes.Scope_Kind,
      Record_Kind => Scopes.Record_Scope,
      Metadata_Type => Boolean,
      Default_Metadata => False);

   type Top_State (Present : Boolean := False) is record
      case Present is
         when True =>
            Kind : Scopes.Scope_Kind;
            Body_Started : Boolean;
         when False =>
            null;
      end case;
   end record;

   subtype Stack is Recognition_Stacks.Stack;

   function Top (Object : Stack) return Top_State;
   procedure Push
     (Object : in out Stack;
      Kind : Scopes.Scope_Kind;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Body_Started : Boolean := False;
      Maximum_Depth : Natural := Natural'Last);
   procedure Close
     (Object : in out Stack;
      Ending_Name : Ada.Strings.Unbounded.Unbounded_String);
   procedure Close_Record (Object : in out Stack);
   procedure Mark_Body_Started (Object : in out Stack);
end Giflib_Tooling.Structural_Recognition;
