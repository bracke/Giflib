with Giflib_Tooling.Budgeted_Names;
with Giflib_Tooling.Call_Analysis;
with Giflib_Tooling.Transition_Access_Inspection;
with Giflib_Tooling.Transition_Call_Inspection;

package body Giflib_Tooling.Transition_Inspection is
   package Names renames Giflib_Tooling.Budgeted_Names;
   package Accesses renames
     Giflib_Tooling.Transition_Access_Inspection;
   package Calls renames Giflib_Tooling.Transition_Call_Inspection;

   procedure Find_Assignment
     (Statement : Source.Token_Vectors.Vector;
      Assignment : out Natural;
      Left_Start : out Positive;
      Budget : in out Budgets.Budget) is
   begin
      Assignment := 0;
      Left_Start := Statement.First_Index;
      for Index in Statement.First_Index .. Statement.Last_Index loop
         Budgets.Charge (Budget);
         if Source.Image (Statement (Index)) = ":=" then
            Assignment := Index;
            exit;
         end if;
      end loop;
      if Assignment > 0 then
         for Index in Statement.First_Index .. Assignment - 1 loop
            Budgets.Charge (Budget);
            if Source.Image (Statement (Index)) in "then" | "else" | "=>" then
               Left_Start := Index + 1;
            end if;
         end loop;
      end if;
   end Find_Assignment;

   function Analyze
     (Statement : Source.Token_Vectors.Vector;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Session_Names : Syntax.Name_Vectors.Vector;
      Policy : Giflib_Tooling.Transition_Policy.Policy;
      Unit_Name : String;
      Trusted_Local_Names : Syntax.Name_Vectors.Vector;
      Seen : in out Syntax.Name_Vectors.Vector;
      Budget : in out Budgets.Budget) return Boolean
   is
      Assignment : Natural;
      Left_Start : Positive;
   begin
      if Statement.Is_Empty then
         return False;
      end if;
      Find_Assignment (Statement, Assignment, Left_Start, Budget);
      for Index in Statement.First_Index .. Statement.Last_Index loop
         Budgets.Charge (Budget);
         if Names.Contains
           (Session_Names, Source.Image (Statement (Index)), Budget)
         then
            declare
               Has_Field : constant Boolean :=
                 Accesses.Has_Protected_Field
                   (Statement, Index, Protected_Fields, Budget);
               Prefix_Length : constant Natural :=
                 Index - Statement.First_Index + 1;
            begin
               Budgets.Charge_Scan (Budget, Prefix_Length);
               declare
                  Callee_Result : constant Giflib_Tooling.Call_Analysis.Callee_Result :=
                    Calls.Callee (Statement, Index);
               begin
                  if not Calls.In_Subprogram_Profile
                    (Statement, Index, Budget)
                  then
                     Calls.Record_Allowed
                       (Callee_Result, Unit_Name, Policy, Seen, Budget);
                  end if;
                  if Accesses.Violates
                    (Statement, Index, Protected_Fields, Has_Field,
                     Assignment, Left_Start, Callee_Result,
                     Trusted_Local_Names, Unit_Name, Policy, Budget)
                  then
                     return True;
                  end if;
               end;
            end;
         end if;
      end loop;
      return False;
   end Analyze;

   function Violation
     (Statement : Source.Token_Vectors.Vector;
      Protected_Fields : Syntax.Name_Vectors.Vector;
      Session_Names : Syntax.Name_Vectors.Vector;
      Policy : Giflib_Tooling.Transition_Policy.Policy;
      Unit_Name : String := "";
      Trusted_Local_Names : Syntax.Name_Vectors.Vector :=
        Syntax.Name_Vectors.Empty_Vector) return Boolean
   is
      Ignored : Syntax.Name_Vectors.Vector;
      Budget : Budgets.Budget;
   begin
      return Analyze
        (Statement, Protected_Fields, Session_Names, Policy, Unit_Name,
         Trusted_Local_Names, Ignored, Budget);
   end Violation;
end Giflib_Tooling.Transition_Inspection;
