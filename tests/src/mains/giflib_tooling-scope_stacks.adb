package body Giflib_Tooling.Scope_Stacks is
   package body Models is
      use Ada.Strings.Unbounded;

      function Depth (Object : Stack) return Natural is
        (Natural (Object.Items.Length));

      function Top (Object : Stack) return Optional_Frame is
        (if Object.Items.Is_Empty
         then (Present => False)
         else (Present => True, Value => Object.Items.Last_Element));

      procedure Push
        (Object : in out Stack;
         Kind : Kind_Type;
         Name : Unbounded_String;
         Metadata : Metadata_Type := Default_Metadata;
         Maximum_Depth : Natural := Natural'Last) is
      begin
         if Natural (Object.Items.Length) >= Maximum_Depth then
            raise Input_Error with "structural scope depth limit exceeded";
         end if;
         Object.Items.Append (Frame'(Kind, Name, Metadata));
      end Push;

      procedure Close
        (Object : in out Stack;
         Ending_Name : Unbounded_String;
         Result : out Optional_Frame) is
      begin
         Result := (Present => False);
         if Object.Items.Is_Empty then
            raise Input_Error with
              (if Length (Ending_Name) > 0
               then "structural scope ending name mismatch: " &
                 To_String (Ending_Name) & "/<empty>"
               else "structural scope ending without active scope");
         elsif Object.Items.Last_Element.Kind = Record_Kind then
            raise Input_Error with "record scope requires end record";
         elsif Length (Ending_Name) > 0
           and then Ending_Name /= Object.Items.Last_Element.Name
         then
            raise Input_Error with
              "structural scope ending name mismatch: " &
              To_String (Ending_Name) & "/" &
              To_String (Object.Items.Last_Element.Name);
         end if;
         Result := (Present => True, Value => Object.Items.Last_Element);
         Object.Items.Delete_Last;
      end Close;

      procedure Close_Record
        (Object : in out Stack; Result : out Optional_Frame) is
      begin
         if not Object.Items.Is_Empty
           and then Object.Items.Last_Element.Kind = Record_Kind
         then
            Result := (Present => True, Value => Object.Items.Last_Element);
            Object.Items.Delete_Last;
         else
            raise Input_Error with "record ending without active record scope";
         end if;
      end Close_Record;

      procedure Set_Top_Metadata
        (Object : in out Stack; Metadata : Metadata_Type)
      is
         Item : Frame;
      begin
         if not Object.Items.Is_Empty then
            Item := Object.Items.Last_Element;
            Item.Metadata := Metadata;
            Object.Items.Replace_Element (Object.Items.Last_Index, Item);
         end if;
      end Set_Top_Metadata;
   end Models;
end Giflib_Tooling.Scope_Stacks;
