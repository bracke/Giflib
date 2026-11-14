with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Contexts;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_State.Bindings;
with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Session_State.Resolution;
with Giflib_Tooling.Session_Type_Indications;
with Giflib_Tooling.Token_Navigation;

package body Giflib_Tooling.Session_Type_Declarations is
   use Ada.Strings.Unbounded;
   use Semantics;
   use State;
   use type Source.Token_Kind;
   package Contexts renames Giflib_Tooling.Session_Contexts;
   package Indications renames Giflib_Tooling.Session_Type_Indications;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Resolution renames Giflib_Tooling.Session_State.Resolution;
   package Navigation renames Giflib_Tooling.Token_Navigation;
   use Giflib_Tooling.Session_State.Bindings;
   use Giflib_Tooling.Session_State.Scopes;

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Object : in out State.State;
      Context : in out Type_Classification_Vectors.Vector;
      Budget : in out Budgets.Budget;
      Unit_Scope : String)
   is
      Is_Marker : constant Navigation.Optional_Position :=
        Navigation.Before_Outer_Semicolon
          (Tokens, Index + 2, "is", Budget);
      Semicolon : constant Navigation.Optional_Position :=
        Navigation.Before_Outer_Semicolon
          (Tokens, Index + 2, ";", Budget);
      Eligible : Boolean := Source.Image (Tokens (Index)) = "subtype";
      Session_Nesting : Session_Depth := No_Session_Depth;
      Related_Type : Unbounded_String;
      Array_Marker : Navigation.Optional_Position;
      Of_Marker : Navigation.Optional_Position;
   begin
      for Pass in 1 .. 4 loop
         Budgets.Charge_Scan
           (Budget, Tokens.Last_Index - Index + 1);
      end loop;
      if Index = Tokens.Last_Index
        or else Source.Kind_Of (Tokens (Index + 1)) /= Source.Identifier
      then
         return;
      end if;
      if Is_Marker.Present then
         for Cursor in Is_Marker.Value + 1 ..
           (if Semicolon.Present
                and then Semicolon.Value > Is_Marker.Value
            then Semicolon.Value - 1 else Tokens.Last_Index)
         loop
            exit when Source.Image (Tokens (Cursor)) in
              "record" | "array" | "interface" | "range" | "digits" |
              "delta" | "(";
            if Source.Image (Tokens (Cursor)) in "access" | "new" then
               Eligible := True;
               exit;
            end if;
         end loop;
         for Cursor in Is_Marker.Value + 1 ..
           (if Semicolon.Present
                and then Semicolon.Value > Is_Marker.Value
            then Semicolon.Value - 1 else Tokens.Last_Index)
         loop
            if Source.Image (Tokens (Cursor)) = "array" then
               Array_Marker := (Present => True, Value => Cursor);
            elsif Array_Marker.Present
              and then Source.Image (Tokens (Cursor)) = "of"
            then
               Of_Marker := (Present => True, Value => Cursor);
               exit;
            end if;
         end loop;
         if Of_Marker.Present then
            declare
               Last : constant Positive :=
                 (if Semicolon.Present
                      and then Semicolon.Value > Of_Marker.Value
                  then Semicolon.Value - 1 else Tokens.Last_Index);
               Type_Info : constant Indications.Indication :=
                 Indications.Analyze
                   (Tokens, Of_Marker.Value + 1, Last, Object, Budget);
            begin
               if Type_Info.Depth < No_Session_Depth then
                  Session_Nesting := Nested (Type_Info.Depth);
               end if;
               Related_Type := Type_Info.Declared_Type;
            end;
         elsif Eligible then
            declare
               Last : constant Positive :=
                 (if Semicolon.Present
                      and then Semicolon.Value > Is_Marker.Value
                  then Semicolon.Value - 1 else Tokens.Last_Index);
            begin
               declare
                  Type_Info : constant Indications.Indication :=
                    Indications.Analyze
                      (Tokens, Is_Marker.Value + 1, Last, Object, Budget);
               begin
                  Session_Nesting := Type_Info.Depth;
                  Related_Type := Type_Info.Declared_Type;
               end;
            end;
         end if;
      end if;
      Bind_Type
        (Object, Source.Text_Of (Tokens (Index + 1)), Session_Nesting,
         Declared_Type => Source.Image (Tokens (Index + 1)),
         Budget => Budget,
         Related_Type => To_String (Related_Type));
      if Is_Context_Level (Object) then
         Contexts.Set_Type
           (Context, Source.Text_Of (Tokens (Index + 1)), Session_Nesting,
            Source.Text_Of (Tokens (Index + 1)), Related_Type, Budget);
         if Unit_Scope /= "" then
            declare
               Qualified_Name : constant Unbounded_String :=
                 To_Unbounded_String
                   (Identity.Qualified_Declaration
                      (Unit_Scope, Source.Image (Tokens (Index + 1))));
               Related_Name : Unbounded_String := Related_Type;
            begin
               if Length (Related_Name) > 0
                 and then Ada.Strings.Fixed.Index
                   (To_String (Related_Name), ".") = 0
               then
                  declare
                     Candidate : constant String :=
                       Identity.Qualified_Declaration
                         (Unit_Scope, To_String (Related_Name));
                  begin
                     if Length
                       (Resolution.Visible_Relation
                          (Object, Type_Binding,
                           Candidate, Budget).Declared_Type) > 0
                     then
                        Related_Name := To_Unbounded_String (Candidate);
                     end if;
                  end;
               end if;
               Bind_Type
                 (Object, Qualified_Name, Session_Nesting,
                  Declared_Type => To_String (Qualified_Name),
                  Budget => Budget,
                  Related_Type => To_String (Related_Name));
               Contexts.Set_Type
                 (Context, Qualified_Name, Session_Nesting,
                  Qualified_Name, Related_Name, Budget);
            end;
         end if;
      end if;
   end Add;
end Giflib_Tooling.Session_Type_Declarations;
