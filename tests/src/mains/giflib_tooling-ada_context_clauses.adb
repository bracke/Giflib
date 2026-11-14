with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Lexing;
with Giflib_Tooling.Source_Tokens;

package body Giflib_Tooling.Ada_Context_Clauses is
   package Lexing renames Giflib_Tooling.Source_Lexing;
   package Source renames Giflib_Tooling.Source_Tokens;
   use type Source.Token_Kind;

   function Units_From
     (Tokens : Source.Token_Vectors.Vector)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is
      use Ada.Strings.Unbounded;
      Result : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;

      function Starts_Context_Clause (Index : Positive) return Boolean is
         Cursor : Natural := Index;
      begin
         if Index = Tokens.First_Index then
            return True;
         end if;
         Cursor := Index - 1;
         while Cursor >= Tokens.First_Index
           and then Source.Image (Tokens (Positive (Cursor))) in
             "limited" | "private"
         loop
            exit when Cursor = Tokens.First_Index;
            Cursor := Cursor - 1;
         end loop;
         return
           (Cursor = Tokens.First_Index
            and then Source.Image (Tokens (Positive (Cursor))) in
              "limited" | "private")
           or else Source.Image (Tokens (Positive (Cursor))) = ";";
      end Starts_Context_Clause;

      procedure Collect (First : Positive) is
         Unit_Name : Unbounded_String;
         Expect_Name : Boolean := True;
         Cursor : Positive := First;
      begin
         while Cursor <= Tokens.Last_Index loop
            if Expect_Name
              and then Source.Kind_Of (Tokens (Cursor)) = Source.Identifier
            then
               Append (Unit_Name, Source.Image (Tokens (Cursor)));
               Expect_Name := False;
            elsif not Expect_Name and then Source.Image (Tokens (Cursor)) = "."
            then
               Append (Unit_Name, ".");
               Expect_Name := True;
            elsif not Expect_Name
              and then Source.Image (Tokens (Cursor)) in "," | ";"
            then
               Result.Append (Unit_Name);
               Unit_Name := Null_Unbounded_String;
               Expect_Name := True;
               exit when Source.Image (Tokens (Cursor)) = ";";
            else
               return;
            end if;
            exit when Cursor = Tokens.Last_Index;
            Cursor := Cursor + 1;
         end loop;
      end Collect;
   begin
      if Tokens.Is_Empty then
         return Result;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index loop
         if Source.Image (Tokens (Index)) = "with"
           and then Starts_Context_Clause (Index)
           and then Index < Tokens.Last_Index
         then
            Collect (Index + 1);
         end if;
      end loop;
      return Result;
   end Units_From;

   function Units
     (Text : String) return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is (Units_From (Lexing.Lex (Text)));

   function Units
     (Parsed : Giflib_Tooling.Source_Model.Parsed_Source)
      return Giflib_Tooling.Name_Collections.Name_Vectors.Vector
   is
      Result : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      procedure Inspect (Tokens : Source.Token_Vectors.Vector) is
      begin
         Result := Units_From (Tokens);
      end Inspect;
   begin
      Giflib_Tooling.Source_Model.Inspect_Tokens (Parsed, Inspect'Access);
      return Result;
   end Units;
end Giflib_Tooling.Ada_Context_Clauses;
