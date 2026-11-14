with Giflib_Tooling.Structural_Bodies;

package body Giflib_Tooling.Structural_Construct_Actions is
   use Ada.Strings.Unbounded;
   package Bodies renames Giflib_Tooling.Structural_Bodies;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Recognition renames Giflib_Tooling.Structural_Recognition;
   package Scopes renames Recognition.Scopes;
   package Source renames Giflib_Tooling.Source_Tokens;
   package Subprograms renames Giflib_Tooling.Structural_Subprograms;
   use type Scopes.Scope_Kind;
   use type Source.Token_Kind;

   function Ending_Name
     (Tokens : Source.Token_Vectors.Vector;
      Start : Positive;
      Budget : in out Budgets.Budget) return Unbounded_String
   is
      Result : Unbounded_String;
   begin
      for Cursor in Start + 1 .. Tokens.Last_Index loop
         Budgets.Charge (Budget);
         exit when Source.Image (Tokens (Cursor)) = ";";
         if Source.Kind_Of (Tokens (Cursor)) = Source.Identifier then
            Result := Source.Text_Of (Tokens (Cursor));
         end if;
      end loop;
      return Result;
   end Ending_Name;

   function Label_Name
     (Tokens : Source.Token_Vectors.Vector; Index : Positive)
      return Unbounded_String is
     (if Index >= Tokens.First_Index + 2
        and then Source.Image (Tokens (Index - 1)) = ":"
        and then Source.Kind_Of (Tokens (Index - 2)) = Source.Identifier
      then Source.Text_Of (Tokens (Index - 2))
      else Null_Unbounded_String);

   function Is_Access_Subprogram
     (Tokens : Source.Token_Vectors.Vector; Index : Positive) return Boolean is
     (Index > Tokens.First_Index
      and then
        (Source.Image (Tokens (Index - 1)) = "access"
         or else
           (Source.Image (Tokens (Index - 1)) = "protected"
            and then Index >= Tokens.First_Index + 2
            and then Source.Image (Tokens (Index - 2)) = "access")));

   function Recognize_End
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Budget : in out Budgets.Budget) return Action is
   begin
      if Source.Image (Tokens (Index)) /= "end" then
         return (Kind => No_Action);
      elsif Source.Image (Tokens (Index + 1)) = "record" then
         return (Kind => End_Record);
      elsif Source.Image (Tokens (Index + 1)) = "loop" then
         return (Kind => End_Loop);
      elsif Source.Image (Tokens (Index + 1)) = "return" then
         return (Kind => End_Return);
      elsif Source.Image (Tokens (Index + 1)) in "if" | "case" | "select"
      then
         return (Kind => End_Control);
      else
         return
           (Kind => End_Scope,
            Ending_Name => Ending_Name (Tokens, Index, Budget));
      end if;
   end Recognize_End;

   function Recognize_Declaration
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Budget : in out Budgets.Budget) return Action
   is
      Image : constant String := Source.Image (Tokens (Index));
   begin
      if Image in "procedure" | "function"
        and then Source.Kind_Of (Tokens (Index + 1)) = Source.Identifier
        and then not Is_Access_Subprogram (Tokens, Index)
      then
         return
           (Kind => Start_Subprogram,
            Subprogram_Name => Source.Text_Of (Tokens (Index + 1)),
            Header => Subprograms.Analyze (Tokens, Index, Budget));
      elsif Image = "package" and then Index + 2 <= Tokens.Last_Index then
         declare
            Name_Index : Positive :=
              (if Source.Image (Tokens (Index + 1)) = "body"
               then Index + 2 else Index + 1);
         begin
            loop
               Budgets.Charge (Budget);
               exit when Name_Index + 2 > Tokens.Last_Index
                 or else Source.Image (Tokens (Name_Index + 1)) /= "."
                 or else Source.Kind_Of (Tokens (Name_Index + 2)) /=
                   Source.Identifier;
               Name_Index := Name_Index + 2;
            end loop;
            if Source.Kind_Of (Tokens (Name_Index)) = Source.Identifier then
               return
                 (Kind => Start_Package,
                  Package_Name => Source.Text_Of (Tokens (Name_Index)),
                  Introduces_Scope =>
                    Bodies.Introduces_Body (Tokens, Index, Budget),
                  Is_Body => Source.Image (Tokens (Index + 1)) = "body");
            end if;
         end;
      elsif Image in "task" | "protected" then
         declare
            Name_Index : constant Positive :=
              (if Source.Image (Tokens (Index + 1)) in "body" | "type"
               then Index + 2 else Index + 1);
         begin
            if Name_Index <= Tokens.Last_Index
              and then Source.Kind_Of (Tokens (Name_Index)) = Source.Identifier
              and then Bodies.Introduces_Body (Tokens, Index, Budget)
            then
               return
                 (Kind => Start_Program,
                  Program_Name => Source.Text_Of (Tokens (Name_Index)));
            end if;
         end;
      end if;
      return (Kind => No_Action);
   end Recognize_Declaration;

   function Recognize_Block
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Top : Recognition.Top_State;
      In_Type_Declaration : Boolean;
      Type_Name : Unbounded_String) return Action
   is
      Image : constant String := Source.Image (Tokens (Index));
   begin
      if Image = "declare" then
         return
           (Kind => Start_Block,
            Block_Name => Label_Name (Tokens, Index),
            Body_Started => False);
      elsif Image = "begin" then
         if not Top.Present
           or else Top.Body_Started
           or else Top.Kind = Scopes.Record_Scope
         then
            return
              (Kind => Start_Block,
               Block_Name => Label_Name (Tokens, Index),
               Body_Started => True);
         end if;
         return (Kind => Mark_Body);
      elsif Image = "record"
        and then (Index = Tokens.First_Index
                  or else Source.Image (Tokens (Index - 1)) not in
                    "end" | "null")
      then
         return
           (Kind => Start_Record,
            Record_Name =>
              (if In_Type_Declaration
               then Type_Name else Null_Unbounded_String));
      end if;
      return (Kind => No_Action);
   end Recognize_Block;

   function Recognize
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Top : Recognition.Top_State;
      In_Type_Declaration : Boolean;
      Type_Name : Unbounded_String;
      Budget : in out Budgets.Budget) return Action
   is
      Result : Action := Recognize_End (Tokens, Index, Budget);
   begin
      if Result.Kind /= No_Action then
         return Result;
      end if;
      Result := Recognize_Declaration (Tokens, Index, Budget);
      if Result.Kind /= No_Action then
         return Result;
      end if;
      return Recognize_Block
        (Tokens, Index, Top, In_Type_Declaration, Type_Name);
   end Recognize;
end Giflib_Tooling.Structural_Construct_Actions;
