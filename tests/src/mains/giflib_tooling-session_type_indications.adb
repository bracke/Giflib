with Giflib_Tooling.Session_Profiles;
with Giflib_Tooling.Session_State.Resolution;

package body Giflib_Tooling.Session_Type_Indications is
   use Ada.Strings.Unbounded;
   use Semantics;
   use State;
   package Profiles renames Giflib_Tooling.Session_Profiles;
   package Resolution renames Giflib_Tooling.Session_State.Resolution;
   use type Profiles.Type_Name_Status;

   function Analyze
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive;
      Object : State.State;
      Budget : in out Budgets.Budget) return Indication
   is
      Raw : Unbounded_String;
      Parsed_Name : Profiles.Type_Name_Result;
      Class_Wide : Boolean;
      Anonymous_Subprogram_Access : Boolean := False;
   begin
      if First > Last then
         return (others => <>);
      end if;
      Budgets.Charge_Scan (Budget, Last - First + 1);
      Parsed_Name := Profiles.Type_Name (Tokens, First, Last);
      if Parsed_Name.Status = Profiles.Anonymous_Subprogram_Access then
         Anonymous_Subprogram_Access := True;
      elsif Parsed_Name.Status = Profiles.Type_Name_Found then
         Raw := Parsed_Name.Name;
      end if;
      Class_Wide := Length (Raw) >= 6
        and then Slice (Raw, Length (Raw) - 5, Length (Raw)) = "'class";
      for Cursor in First .. Last loop
         if Source.Image (Tokens (Cursor)) = "access" then
            for Tail in Cursor + 1 .. Last loop
               if Source.Image (Tokens (Tail)) in "procedure" | "function" then
                  Anonymous_Subprogram_Access := True;
                  exit;
               end if;
            end loop;
            exit;
         end if;
      end loop;
      if Class_Wide then
         Delete (Raw, Length (Raw) - 5, Length (Raw));
      end if;
      if Length (Raw) = 0 then
         return (others => <>);
      end if;
      declare
         Resolved : constant String :=
           Resolution.Resolve_Qualified_Name
             (Object, To_String (Raw), Budget);
         Depth : constant Session_Depth :=
           (if Resolved = "" or else Anonymous_Subprogram_Access
            then No_Session_Depth
            else Resolution.Visible_Relation
              (Object, Type_Binding, Resolved, Budget).Depth);
      begin
         return
           (Depth => Depth,
            Declared_Type => To_Unbounded_String
              ((if Resolved = "" then ""
                elsif Class_Wide then Resolved & "'class"
                else Resolved)));
      end;
   end Analyze;
end Giflib_Tooling.Session_Type_Indications;
