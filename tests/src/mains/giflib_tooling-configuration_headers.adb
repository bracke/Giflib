with Giflib_Tooling.Configuration_Text;

package body Giflib_Tooling.Configuration_Headers is
   package Text renames Giflib_Tooling.Configuration_Text;

   function Parse (Line : String) return Header is
      Starts_Header : constant Boolean :=
        Line'Length > 0 and then Line (Line'First) = '[';
      Ends_Header : constant Boolean :=
        Line'Length > 0 and then Line (Line'Last) = ']';
   begin
      if not Starts_Header and then not Ends_Header then
         return (Kind => Not_A_Header);
      elsif Line'Length >= 4
        and then Line (Line'First .. Line'First + 1) = "[["
        and then Line (Line'Last - 1 .. Line'Last) = "]]"
      then
         declare
            Name : constant String :=
              Text.Trim (Line (Line'First + 2 .. Line'Last - 2));
         begin
            return
              (if Name = ""
               then (Kind => Malformed_Header)
               else
                 (Kind => Valid_Header,
                  Name => Ada.Strings.Unbounded.To_Unbounded_String (Name),
                  Is_Array => True));
         end;
      elsif Line'Length >= 2
        and then Line (Line'First) = '['
        and then Line (Line'Last) = ']'
        and then (Line'Length < 3
                  or else Line (Line'First + 1) /= '[')
        and then (Line'Length < 3 or else Line (Line'Last - 1) /= ']')
      then
         declare
            Name : constant String :=
              Text.Trim (Line (Line'First + 1 .. Line'Last - 1));
         begin
            return
              (if Name = ""
               then (Kind => Malformed_Header)
               else
                 (Kind => Valid_Header,
                  Name => Ada.Strings.Unbounded.To_Unbounded_String (Name),
                  Is_Array => False));
         end;
      end if;
      return (Kind => Malformed_Header);
   end Parse;
end Giflib_Tooling.Configuration_Headers;
