with Ada.Strings.Fixed;

package body Giflib_Tooling.Session_Profiles is
   use Ada.Strings.Unbounded;
   use type Source.Token_Kind;

   function Image (Result : Type_Name_Result) return String is
     (To_String (Result.Name));

   function Simple_Name (Name : String) return String is
      Dot : constant Natural :=
        Ada.Strings.Fixed.Index (Name, ".", Going => Ada.Strings.Backward);
   begin
      return (if Dot = 0 then Name else Name (Dot + 1 .. Name'Last));
   end Simple_Name;

   function Type_Name
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive) return Type_Name_Result
   is
      Result : Unbounded_String;
      Started : Boolean := False;
      Has_Access : Boolean := False;
   begin
      if First > Last then
         return (Status => Type_Name_Absent);
      end if;
      for Cursor in First .. Last loop
         exit when Started and then Source.Image (Tokens (Cursor)) in
           "(" | ":=" | ";" | "renames";
         Has_Access := Has_Access
           or else Source.Image (Tokens (Cursor)) = "access";
         if Has_Access
           and then Source.Image (Tokens (Cursor)) in "procedure" | "function"
         then
            return (Status => Anonymous_Subprogram_Access);
         elsif Source.Kind_Of (Tokens (Cursor)) = Source.Identifier
           and then Source.Image (Tokens (Cursor)) not in
             "in" | "out" | "access" | "aliased" | "constant" | "not" |
             "null" | "all" | "protected"
         then
            if Started
              and then Cursor > Tokens.First_Index
              and then Source.Image (Tokens (Cursor - 1)) not in "." | "'"
            then
               exit;
            end if;
            Append (Result, Source.Image (Tokens (Cursor)));
            Started := True;
         elsif Started and then Source.Image (Tokens (Cursor)) in "." | "'" then
            Append (Result, Source.Image (Tokens (Cursor)));
         elsif Started then
            exit;
         end if;
      end loop;
      return
        (if Length (Result) = 0
         then (Status => Type_Name_Absent)
         else (Status => Type_Name_Found, Name => Result));
   end Type_Name;

   function Build
     (Tokens : Source.Token_Vectors.Vector;
      Function_Index : Positive;
      Return_Index : Positive;
      Profile_Last : Positive) return Semantics.Callable_Profile
   is
      Result : Semantics.Callable_Profile;
      Name_Index : constant Positive := Function_Index + 1;
      Depth : Natural := 0;
      Names_In_Group : Natural := 0;
      Group_Size : Natural := 0;
      Indication_First : Source.Optional_Position;
      Optional : Boolean := False;

      procedure Finish_Group (Last : Natural) is
         Parsed : constant Type_Name_Result :=
           (if Group_Size = 0 or else not Indication_First.Present
            then (Status => Type_Name_Absent)
            else Type_Name
              (Tokens, Indication_First.Value, Positive (Last)));
         Formal_Type : constant Unbounded_String :=
           (if Parsed.Status = Type_Name_Found
            then Parsed.Name
            else Null_Unbounded_String);
      begin
         if Group_Size > 0 then
            for Unused in 1 .. Group_Size loop
               Result.Formal_Types.Append (Formal_Type);
            end loop;
            Result.Maximum_Arguments := Result.Maximum_Arguments + Group_Size;
            if not Optional then
               Result.Minimum_Arguments := Result.Minimum_Arguments + Group_Size;
            end if;
         end if;
         Names_In_Group := 0;
         Group_Size := 0;
         Indication_First := Source.No_Position;
         Optional := False;
      end Finish_Group;
   begin
      for Cursor in Function_Index .. Profile_Last loop
         if Length (Result.Text) > 0 then
            Append (Result.Text, " ");
         end if;
         Append (Result.Text, Source.Image (Tokens (Cursor)));
      end loop;
      for Cursor in Name_Index + 1 .. Return_Index - 1 loop
         if Source.Image (Tokens (Cursor)) = "(" then
            Depth := Depth + 1;
         elsif Source.Image (Tokens (Cursor)) = ")" then
            if Depth = 1 then
               Finish_Group (Cursor - 1);
            end if;
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
         elsif Depth = 1 and then Source.Image (Tokens (Cursor)) = ";" then
            Finish_Group (Cursor - 1);
         elsif Depth = 1 and then Source.Image (Tokens (Cursor)) = ":" then
            Group_Size := Names_In_Group;
            Indication_First := (Present => True, Value => Cursor + 1);
         elsif Depth = 1 and then Source.Image (Tokens (Cursor)) = ":=" then
            Optional := True;
         elsif Depth = 1 and then not Indication_First.Present
           and then Source.Kind_Of (Tokens (Cursor)) = Source.Identifier
         then
            Names_In_Group := Names_In_Group + 1;
         end if;
      end loop;
      return Result;
   end Build;
end Giflib_Tooling.Session_Profiles;
