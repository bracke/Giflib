with Giflib_Tooling.Budgeted_Names;

package body Giflib_Tooling.Transition_Access_Inspection is
   package Names renames Giflib_Tooling.Budgeted_Names;
   package Calls renames Giflib_Tooling.Call_Analysis;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Policy renames Giflib_Tooling.Transition_Policy;
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;
   use type Source.Token_Kind;

   function Is_Selection_Name (Item : Source.Token) return Boolean is
     (Source.Kind_Of (Item) = Source.Identifier
      or else
        (Source.Kind_Of (Item) = Source.Reserved_Word
         and then Source.Image (Item) = "all"));

   function Has_Protected_Access_Attribute
     (Statement : Source.Token_Vectors.Vector;
      Root : Positive;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Budget : in out Budgets.Budget) return Boolean
   is
      Cursor : Positive := Root + 1;
      Depth : Natural := 0;
      Selected : Boolean := False;
      Is_Protected : Boolean := False;
   begin
      while Cursor <= Statement.Last_Index loop
         Budgets.Charge (Budget);
         if Source.Image (Statement (Cursor)) = "."
           and then Cursor < Statement.Last_Index
           and then Is_Selection_Name (Statement (Cursor + 1))
         then
            if not Selected
              and then Source.Image (Statement (Cursor + 1)) /= "all"
            then
               Is_Protected := Names.Contains
                 (Protected_Fields, Source.Image (Statement (Cursor + 1)),
                  Budget);
               Selected := True;
            end if;
            Cursor := Cursor + 2;
         elsif Source.Image (Statement (Cursor)) = "(" then
            Depth := Depth + 1;
            Cursor := Cursor + 1;
         elsif Source.Image (Statement (Cursor)) = ")" then
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
            Cursor := Cursor + 1;
         elsif Depth = 0
           and then Source.Image (Statement (Cursor)) = "'"
           and then Cursor < Statement.Last_Index
           and then Source.Image (Statement (Cursor + 1)) in
             "access" | "unchecked_access" | "unrestricted_access" |
             "address"
         then
            return not Selected or else Is_Protected;
         elsif Depth > 0 then
            Cursor := Cursor + 1;
         else
            exit;
         end if;
      end loop;
      return False;
   end Has_Protected_Access_Attribute;

   function Has_Protected_Field
     (Statement : Source.Token_Vectors.Vector;
      Root : Positive;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Budget : in out Budgets.Budget) return Boolean
   is
      Cursor : Positive := Root + 1;
   begin
      loop
         exit when Cursor + 1 > Statement.Last_Index;
         Budgets.Charge (Budget);
         exit when Source.Image (Statement (Cursor)) /= "."
           or else not Is_Selection_Name (Statement (Cursor + 1));
         if Source.Image (Statement (Cursor + 1)) = "all" then
            Cursor := Cursor + 2;
         else
            return Names.Contains
              (Protected_Fields, Source.Image (Statement (Cursor + 1)),
               Budget);
         end if;
      end loop;
      return False;
   end Has_Protected_Field;

   function Is_Explicit_Whole_View
     (Statement : Source.Token_Vectors.Vector;
      Root : Positive;
      Budget : in out Budgets.Budget) return Boolean
   is
      Cursor : Positive := Root + 1;
      Dereferenced : Boolean := False;
   begin
      loop
         exit when Cursor + 1 > Statement.Last_Index;
         Budgets.Charge (Budget);
         exit when Source.Image (Statement (Cursor)) /= "."
           or else Source.Image (Statement (Cursor + 1)) /= "all";
         Dereferenced := True;
         Cursor := Cursor + 2;
      end loop;
      return Dereferenced
        and then (Cursor > Statement.Last_Index
                  or else Source.Image (Statement (Cursor)) /= ".");
   end Is_Explicit_Whole_View;

   function Violates
     (Statement : Source.Token_Vectors.Vector;
      Actual : Positive;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Has_Protected_Field : Boolean;
      Assignment : Natural;
      Left_Start : Positive;
      Callee : Calls.Callee_Result;
      Trusted_Local_Names : Syntax.Name_Vectors.Vector;
      Unit_Name : String;
      Policy_Set : Policy.Policy;
      Budget : in out Budgets.Budget) return Boolean
   is
      On_Left : constant Boolean :=
        Assignment > 0 and then Actual >= Left_Start and then Actual < Assignment;

      function Is_Disallowed_Call return Boolean is
      begin
         case Callee.Status is
            when Calls.No_Callee =>
               return False;
            when Calls.Unrecognized_Callee =>
               return True;
            when Calls.Callee_Found =>
               declare
                  Name : constant String := Calls.Image (Callee);
               begin
                  return not Policy.Is_Allowed_Call
                    (Policy_Set, Name, Unit_Name)
                    and then not Names.Contains
                      (Trusted_Local_Names, Name, Budget);
               end;
         end case;
      end Is_Disallowed_Call;
   begin
      if Has_Protected_Access_Attribute
        (Statement, Actual, Protected_Fields, Budget)
        or else (Actual > Statement.First_Index
                 and then Source.Image (Statement (Actual - 1)) = "renames")
      then
         return True;
      elsif Actual < Statement.Last_Index
        and then Source.Image (Statement (Actual + 1)) = ":"
      then
         return False;
      elsif On_Left
        and then Actual < Statement.Last_Index
        and then Source.Image (Statement (Actual + 1)) = ":="
      then
         return True;
      elsif Has_Protected_Field then
         if On_Left
           or else (Actual > Statement.First_Index
                    and then Source.Image (Statement (Actual - 1)) = "renames")
         then
            return True;
         end if;
         return Is_Disallowed_Call;
      elsif Actual = Statement.Last_Index
        or else Source.Image (Statement (Actual + 1)) /= "."
        or else Is_Explicit_Whole_View (Statement, Actual, Budget)
      then
         return Is_Disallowed_Call;
      end if;
      return False;
   end Violates;
end Giflib_Tooling.Transition_Access_Inspection;
