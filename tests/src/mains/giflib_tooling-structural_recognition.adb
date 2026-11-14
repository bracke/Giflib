package body Giflib_Tooling.Structural_Recognition is
   function Top (Object : Stack) return Top_State is
      Item : constant Recognition_Stacks.Optional_Frame :=
        Recognition_Stacks.Top (Object);
   begin
      if not Item.Present then
         return (Present => False);
      end if;
      return
        (Present => True,
         Kind => Item.Value.Kind,
         Body_Started => Item.Value.Metadata);
   end Top;

   procedure Push
     (Object : in out Stack;
      Kind : Scopes.Scope_Kind;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Body_Started : Boolean := False;
      Maximum_Depth : Natural := Natural'Last) is
   begin
      Recognition_Stacks.Push
        (Object, Kind, Name, Metadata => Body_Started,
         Maximum_Depth => Maximum_Depth);
   end Push;

   procedure Close
     (Object : in out Stack;
      Ending_Name : Ada.Strings.Unbounded.Unbounded_String)
   is
      Ignored : Recognition_Stacks.Optional_Frame;
   begin
      Recognition_Stacks.Close (Object, Ending_Name, Ignored);
   end Close;

   procedure Close_Record (Object : in out Stack) is
      Ignored : Recognition_Stacks.Optional_Frame;
   begin
      Recognition_Stacks.Close_Record (Object, Ignored);
   end Close_Record;

   procedure Mark_Body_Started (Object : in out Stack) is
   begin
      Recognition_Stacks.Set_Top_Metadata (Object, True);
   end Mark_Body_Started;
end Giflib_Tooling.Structural_Recognition;
