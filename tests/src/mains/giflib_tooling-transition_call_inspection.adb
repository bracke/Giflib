with Ada.Strings.Unbounded;

with Giflib_Tooling.Budgeted_Names;
package body Giflib_Tooling.Transition_Call_Inspection is
   package Names renames Giflib_Tooling.Budgeted_Names;
   package Budgets renames Giflib_Tooling.Work_Budgets;
   package Calls renames Giflib_Tooling.Call_Analysis;
   use type Calls.Callee_Status;
   package Policy renames Giflib_Tooling.Transition_Policy;
   package Source renames Giflib_Tooling.Source_Tokens;
   package Syntax renames Giflib_Tooling.Name_Collections;

   function Callee
     (Statement : Source.Token_Vectors.Vector;
      Actual : Positive) return Calls.Callee_Result is
     (Calls.Enclosing_Callee (Statement, Actual));

   function In_Subprogram_Profile
     (Statement : Source.Token_Vectors.Vector;
      Actual : Positive;
      Budget : in out Budgets.Budget) return Boolean
   is
      Depth : Natural := 0;
      In_Profile : Boolean := False;
   begin
      for Index in Statement.First_Index .. Actual loop
         Budgets.Charge (Budget);
         if Depth = 0
           and then Source.Image (Statement (Index)) in
             "procedure" | "function"
         then
            In_Profile := True;
         elsif Depth = 0
           and then Source.Image (Statement (Index)) in
             "is" | "renames" | "begin"
         then
            In_Profile := False;
         end if;
         if Source.Image (Statement (Index)) = "(" then
            Depth := Depth + 1;
         elsif Source.Image (Statement (Index)) = ")" and then Depth > 0 then
            Depth := Depth - 1;
         end if;
      end loop;
      return In_Profile;
   end In_Subprogram_Profile;

   procedure Record_Allowed
     (Callee : Calls.Callee_Result;
      Unit_Name : String;
      Policy_Set : Policy.Policy;
      Seen : in out Syntax.Name_Vectors.Vector;
      Budget : in out Budgets.Budget)
   is
   begin
      if Callee.Status /= Calls.Callee_Found then
         return;
      end if;
      declare
         Name : constant String := Calls.Image (Callee);
         Family : constant Policy.Family_Match :=
           Policy.Allowed_Family (Policy_Set, Name, Unit_Name);
      begin
         if Policy.Is_Global_Allowed_Call (Policy_Set, Name) then
            Names.Include (Seen, "global:" & Name, Budget);
         end if;
         if Family.Found then
            Names.Include
              (Seen,
               "family:" & Ada.Strings.Unbounded.To_String (Family.Prefix)
                 & ":" & Name,
               Budget);
         end if;
      end;
   end Record_Allowed;
end Giflib_Tooling.Transition_Call_Inspection;
