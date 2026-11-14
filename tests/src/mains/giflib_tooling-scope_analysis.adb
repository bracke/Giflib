with Giflib_Tooling.Source_Events;
with Giflib_Tooling.Scope_Walking;
with Giflib_Tooling.Structural_Scopes;

package body Giflib_Tooling.Scope_Analysis is
   use Ada.Strings.Unbounded;
   package Nesting renames Giflib_Tooling.Structural_Scopes;
   package Walking renames Giflib_Tooling.Scope_Walking;
   use type Nesting.Scope_Kind;
   use type Nesting.Scope_Id;

   function Current_Declaration_Scope
     (Scopes : Nesting.Scope_Stack) return Declaration_Scope
   is
      Current : constant Nesting.Optional_Scope_Frame := Nesting.Top (Scopes);
   begin
      return
        (if Nesting.Depth (Scopes) = 1
           and then Current.Present
           and then Current.Value.Kind = Nesting.Package_Scope
         then Package_Unit_Declaration
         elsif Nesting.Depth (Scopes) = 0
         then Outside_Declaration_Scope
         else Nested_Declaration);
   end Current_Declaration_Scope;

   function Declaration_Scopes
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Declaration_Scope_Vectors.Vector
   is
      Result : Declaration_Scope_Vectors.Vector;
      procedure Visit
        (Token : Giflib_Tooling.Source_Tokens.Token;
         Index : Positive;
         Scopes : Nesting.Scope_Stack) is
         pragma Unreferenced (Token, Index);
      begin
         Result.Append (Current_Declaration_Scope (Scopes));
      end Visit;
   begin
      Walking.Walk (Parsed, Budget, Visit_Token => Visit'Access);
      return Result;
   end Declaration_Scopes;

   procedure Scan_Declarations
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Process : not null access procedure
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Scope_At : Declaration_Scope_Vectors.Vector))
   is
      Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
      Statement_Scopes : Declaration_Scope_Vectors.Vector;

      procedure Visit
        (Token : Giflib_Tooling.Source_Tokens.Token;
         Index : Positive;
         Scopes : Nesting.Scope_Stack) is
         pragma Unreferenced (Index);
      begin
         if Giflib_Tooling.Source_Tokens.Image (Token) = ";" then
            if not Statement.Is_Empty then
               Process (Statement, Statement_Scopes);
               Statement.Clear;
               Statement_Scopes.Clear;
            end if;
         else
            Statement.Append (Token);
            Statement_Scopes.Append (Current_Declaration_Scope (Scopes));
         end if;
      end Visit;
   begin
      Walking.Walk (Parsed, Budget, Visit_Token => Visit'Access);
      if not Statement.Is_Empty then
         Process (Statement, Statement_Scopes);
      end if;
   end Scan_Declarations;

   function Subprogram_Ranges
     (Parsed : Source.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget)
      return Subprogram_Range_Vectors.Vector
   is
      Result : Subprogram_Range_Vectors.Vector;
      type Optional_Position (Present : Boolean := False) is record
         case Present is
            when True =>
               Value : Positive;
            when False =>
               null;
         end case;
      end record;
      type Range_Builder is record
         Name : Unbounded_String;
         Profile : Unbounded_String;
         First : Positive;
         Body_First : Optional_Position;
         Last : Optional_Position;
         Depth : Natural := 0;
         Directly_In_Package : Boolean := False;
         Is_Generic : Boolean := False;
      end record;
      package Range_Builder_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Range_Builder);
      Builders : Range_Builder_Vectors.Vector;
      Pending_Generic_Depth : Natural := Natural'Last;

      procedure Set_Body_First
        (Index : Positive; Scopes : Nesting.Scope_Stack)
      is
         Current : constant Nesting.Optional_Scope_Frame :=
           Nesting.Top (Scopes);
      begin
         if Current.Present
           and then Current.Value.Kind = Nesting.Subprogram_Scope
           and then Nesting.Id_Of (Current.Value) /= Nesting.No_Scope_Id
         then
            declare
               Position : constant Positive :=
                 Positive
                   (Nesting.Scope_Id'Pos (Nesting.Id_Of (Current.Value)));
               Item : Range_Builder := Builders (Position);
            begin
               if not Item.Body_First.Present then
                  Item.Body_First := (Present => True, Value => Index);
                  Builders.Replace_Element (Position, Item);
               end if;
            end;
         end if;
      end Set_Body_First;

      function Directly_In_Package
        (Scopes : Nesting.Scope_Stack) return Boolean
      is
         Current : constant Nesting.Optional_Scope_Frame :=
           Nesting.Top (Scopes);
      begin
         return Nesting.Depth (Scopes) = 1
           and then Current.Present
           and then Current.Value.Kind = Nesting.Package_Scope;
      end Directly_In_Package;

      procedure Finish_Closed
        (Index : Positive; Closed : Nesting.Optional_Scope_Frame)
      is
      begin
         if Closed.Present
           and then Closed.Value.Kind = Nesting.Subprogram_Scope
           and then Nesting.Id_Of (Closed.Value) /= Nesting.No_Scope_Id
         then
            declare
               Position : constant Positive :=
                 Positive
                   (Nesting.Scope_Id'Pos (Nesting.Id_Of (Closed.Value)));
               Item : Range_Builder := Builders (Position);
            begin
               Item.Last := (Present => True, Value => Index);
               Builders.Replace_Element (Position, Item);
            end;
         end if;
      end Finish_Closed;

      procedure Before_Event
        (Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Event : Giflib_Tooling.Source_Events.Structural_Event;
         Scopes : Nesting.Scope_Stack;
         Subprogram_Id : out Nesting.Scope_Id)
      is
         Is_Generic_Declaration : constant Boolean :=
           Pending_Generic_Depth = Nesting.Depth (Scopes)
           and then
             (Event.Token_Index = Tokens.First_Index
              or else Giflib_Tooling.Source_Tokens.Image
                (Tokens (Event.Token_Index - 1)) /= "with");
      begin
         Subprogram_Id := Nesting.No_Scope_Id;
         case Event.Kind is
            when Giflib_Tooling.Source_Events.Subprogram_Start =>
               Builders.Append
                 (Range_Builder'
                    (Name => Event.Subprogram_Name,
                     Profile => Event.Header.Profile,
                     First => Event.Token_Index,
                     Body_First => (Present => False),
                     Last => (Present => False),
                     Depth => Nesting.Depth (Scopes),
                     Directly_In_Package => Directly_In_Package (Scopes),
                     Is_Generic => Is_Generic_Declaration));
               if Is_Generic_Declaration then
                  Pending_Generic_Depth := Natural'Last;
               end if;
               if Event.Header.Introduces_Scope then
                  Subprogram_Id := Nesting.Scope_Id (Builders.Last_Index);
               end if;
            when Giflib_Tooling.Source_Events.Package_Start =>
               if Is_Generic_Declaration then
                  Pending_Generic_Depth := Natural'Last;
               end if;
            when others =>
               null;
         end case;
      end Before_Event;

      procedure After_Event
        (Event : Giflib_Tooling.Source_Events.Structural_Event;
         Closed : Nesting.Optional_Scope_Frame) is
      begin
         Finish_Closed (Event.Token_Index, Closed);
      end After_Event;

      procedure Visit
        (Token : Giflib_Tooling.Source_Tokens.Token;
         Index : Positive;
         Scopes : Nesting.Scope_Stack) is
      begin
         if Giflib_Tooling.Source_Tokens.Image (Token) = "generic" then
            Pending_Generic_Depth := Nesting.Depth (Scopes);
         elsif Giflib_Tooling.Source_Tokens.Image (Token) = "begin" then
            Set_Body_First (Index, Scopes);
         end if;
      end Visit;
   begin
      Walking.Walk
        (Parsed, Budget,
         Before_Event => Before_Event'Access,
         After_Event => After_Event'Access,
         Visit_Token => Visit'Access);
      for Item of Builders loop
         if Item.Body_First.Present
           and then Item.Last.Present
           and then Item.Last.Value > Item.Body_First.Value
         then
            Result.Append
              (Subprogram_Range'
                 (Complete => True,
                Name => Item.Name,
                Profile => Item.Profile,
                First => Item.First,
                Depth => Item.Depth,
                Directly_In_Package => Item.Directly_In_Package,
                Is_Generic => Item.Is_Generic,
                Body_First => Item.Body_First.Value,
                Last => Item.Last.Value));
         else
            Result.Append
              (Subprogram_Range'
                 (Complete => False,
                Name => Item.Name,
                Profile => Item.Profile,
                First => Item.First,
                Depth => Item.Depth,
                Directly_In_Package => Item.Directly_In_Package,
                Is_Generic => Item.Is_Generic));
         end if;
      end loop;
      return Result;
   end Subprogram_Ranges;
end Giflib_Tooling.Scope_Analysis;
