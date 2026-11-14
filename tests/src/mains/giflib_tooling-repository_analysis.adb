with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Scope_Analysis;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Repository_Analysis is
   package Scopes renames Giflib_Tooling.Scope_Analysis;
   package Source renames Giflib_Tooling.Source_Model;
   package Text_Case renames Giflib_Tooling.Text_Case;

   function Declares_Main
     (Parsed : Source.Parsed_Source;
      Expected_Name : String;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) return Boolean
   is
      Ranges : constant Scopes.Subprogram_Range_Vectors.Vector :=
        Scopes.Subprogram_Ranges (Parsed, Budget);
      Expected_Profile : constant String :=
        "procedure " & Text_Case.Lower (Expected_Name);

      function Is_Parameterless_Profile
        (Profile : Ada.Strings.Unbounded.Unbounded_String) return Boolean
      is
         Value : constant String :=
           Ada.Strings.Unbounded.To_String (Profile);
         Aspect_Prefix : constant String := Expected_Profile & " with ";
      begin
         return Value = Expected_Profile
           or else
             (Value'Length > Aspect_Prefix'Length
              and then Value
                (Value'First .. Value'First + Aspect_Prefix'Length - 1) =
                  Aspect_Prefix);
      end Is_Parameterless_Profile;
   begin
      for Item of Ranges loop
         if Item.Depth = 0
           and then not Item.Directly_In_Package
           and then not Item.Is_Generic
           and then Item.Complete
           and then Item.Last > Item.Body_First
           and then Ada.Strings.Unbounded.To_String (Item.Name) =
             Text_Case.Lower (Expected_Name)
           and then Is_Parameterless_Profile (Item.Profile)
         then
            return True;
         end if;
      end loop;
      return False;
   end Declares_Main;

   function Documented_Executables
     (Text : String) return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is
      Result : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      First : Integer := Text'First;
      In_Inventory : Boolean := False;
      Fence : Character := ASCII.NUL;
      Fence_Length : Natural := 0;
      In_HTML_Comment : Boolean := False;
      Markdown_Whitespace : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (" " & ASCII.HT & ASCII.CR);

      function Marker_Length (Line : String; Marker : Character)
         return Natural
      is
         Cursor : Integer := Line'First;
      begin
         while Cursor <= Line'Last and then Line (Cursor) = Marker loop
            Cursor := Cursor + 1;
         end loop;
         return Natural (Cursor - Line'First);
      end Marker_Length;

      function Visible_Line (Line : String) return String is
         Result : Ada.Strings.Unbounded.Unbounded_String;
         Cursor : Integer := Line'First;
      begin
         while Cursor <= Line'Last loop
            if In_HTML_Comment then
               declare
                  Closing : constant Natural := Ada.Strings.Fixed.Index
                    (Line, "-->", Cursor);
               begin
                  if Closing = 0 then
                     exit;
                  end if;
                  In_HTML_Comment := False;
                  Cursor := Integer (Closing) + 3;
               end;
            else
               declare
                  Opening : constant Natural := Ada.Strings.Fixed.Index
                    (Line, "<!--", Cursor);
               begin
                  if Opening = 0 then
                     Ada.Strings.Unbounded.Append
                       (Result, Line (Cursor .. Line'Last));
                     exit;
                  end if;
                  if Integer (Opening) > Cursor then
                     Ada.Strings.Unbounded.Append
                       (Result, Line (Cursor .. Integer (Opening) - 1));
                  end if;
                  In_HTML_Comment := True;
                  Cursor := Integer (Opening) + 4;
               end;
            end if;
         end loop;
         return Ada.Strings.Unbounded.To_String (Result);
      end Visible_Line;
   begin
      while First <= Text'Last loop
         declare
            Last : Integer := First;
         begin
            while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
               Last := Last + 1;
            end loop;
            declare
               Raw_Line : constant String := Ada.Strings.Fixed.Trim
                 (Text (First .. Last - 1),
                  Ada.Strings.Maps.Null_Set, Markdown_Whitespace);
               Line : constant String :=
                 (if Fence /= ASCII.NUL then Raw_Line
                  else Ada.Strings.Fixed.Trim
                    (Visible_Line (Raw_Line), Ada.Strings.Maps.Null_Set,
                     Markdown_Whitespace));
               Indent : Natural := 0;
            begin
               while Indent < Line'Length
                 and then Line (Line'First + Integer (Indent)) = ' '
               loop
                  Indent := Indent + 1;
               end loop;
               declare
                  Indented_Code : constant Boolean :=
                    Indent >= 4
                    or else
                      (Line'Length > 0
                       and then Line (Line'First) = ASCII.HT);
                  Content : constant String :=
                    (if Indent >= Line'Length then ""
                     else Line
                       (Line'First + Integer (Indent) .. Line'Last));
                  Lower_Content : constant String := Text_Case.Lower (Content);
                  Is_Marker : constant Boolean :=
                    not Indented_Code
                    and then Content'Length >= 3
                    and then Content (Content'First) in '`' | '~'
                    and then Marker_Length
                      (Content, Content (Content'First)) >= 3;
                  Length : constant Natural :=
                    (if Is_Marker
                     then Marker_Length (Content, Content (Content'First))
                     else 0);
               begin
                  if Fence /= ASCII.NUL then
                     if Is_Marker
                       and then Content (Content'First) = Fence
                       and then Length >= Fence_Length
                       and then Length = Content'Length
                     then
                        Fence := ASCII.NUL;
                        Fence_Length := 0;
                     end if;
                  elsif Is_Marker then
                     Fence := Content (Content'First);
                     Fence_Length := Length;
                  elsif Indented_Code then
                     null;
                  elsif Content'Length > 0
                    and then Content (Content'First) = '#'
                  then
                     In_Inventory :=
                       Lower_Content = "### ada tooling inventory";
                  elsif In_Inventory
                    and then Content'Length >= 5
                    and then
                      Content (Content'First .. Content'First + 2) = "- `"
                    and then Content (Content'Last) = '`'
                  then
                     Result.Append
                       (Ada.Strings.Unbounded.To_Unbounded_String
                          (Content
                             (Content'First + 3 .. Content'Last - 1)));
                  end if;
               end;
            end;
            First := Last + 1;
         end;
      end loop;
      return Result;
   end Documented_Executables;
end Giflib_Tooling.Repository_Analysis;
