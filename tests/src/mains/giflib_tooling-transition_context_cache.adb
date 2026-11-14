with Ada.Strings.Unbounded;
with Giflib_Tooling.Transition_Storage;

package body Giflib_Tooling.Transition_Context_Cache is
   use Ada.Strings.Unbounded;
   use type Source.Separate_Clause;
   use type Source.Separate_Clause_Kind;

   procedure Charge_Context_Copy
     (Budget : in out Budgets.Budget;
      Context : Semantics.Type_Classification_Vectors.Vector) is
      Measurement : constant Giflib_Tooling.Transition_Storage
        .Context_Measurement :=
          Giflib_Tooling.Transition_Storage.Measure_Context ("", Context);
   begin
      Budgets.Charge (Budget, Measurement.Copy_Work);
   end Charge_Context_Copy;

   procedure Charge_Key
     (Budget : in out Budgets.Budget;
      Prefix : String;
      Target_Type : Identity.Target;
      Name : String) is
   begin
      Budgets.Charge_Scan (Budget, Prefix'Length);
      Budgets.Charge_Scan (Budget, Identity.Simple_Length (Target_Type));
      Budgets.Charge_Scan (Budget, Identity.Qualified_Length (Target_Type));
      Budgets.Charge_Scan (Budget, Name'Length);
      Budgets.Charge (Budget, 3);
   end Charge_Key;

   function Key_Of
     (Prefix : String;
      Target_Type : Identity.Target;
      Name : String) return String is
     (Prefix & ":" & Identity.Simple_Name (Target_Type) & ":" &
      Identity.Qualified_Name (Target_Type) & ":" & Name);

   function Contains_Clause (Object : Cache; Name : String) return Boolean is
     (Object.Clauses.Contains (Name));

   function Clause_At
     (Object : Cache; Name : String) return Source.Separate_Clause is
     (Object.Clauses.Element (Name));

   procedure Remember_Clause
     (Object : in out Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget;
      Name : String;
      Clause : Source.Separate_Clause) is
   begin
      if Object.Clauses.Contains (Name) then
         if Object.Clauses.Element (Name) /= Clause then
            raise Input_Error with
              "source unit changed during context inspection: " & Name;
         end if;
         return;
      end if;
      Budgets.Charge
        (Budget,
         Name'Length + 1 +
           (if Clause.Kind = Source.Valid_Separate_Clause
            then Length (Clause.Parent) else 0));
      declare
         Retention :
           Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
             Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
      begin
         Giflib_Tooling.Transition_Storage.Charge_Clause
           (Retention, Name, Clause);
         Object.Clauses.Insert (Name, Clause);
         Giflib_Tooling.Validation_Storage_Budgets.Commit (Retention);
      end;
   end Remember_Clause;

   function Load_Deepest_Context
     (Object : Cache;
      Budget : in out Budgets.Budget;
      Prefix : String;
      Target_Type : Identity.Target;
      Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
      return Context_Lookup is
   begin
      if Names.Is_Empty then
         return (Found => False);
      end if;
      for Index in reverse Names.First_Index .. Names.Last_Index loop
         declare
            Name : constant String := To_String (Names (Index));
         begin
            Charge_Key (Budget, Prefix, Target_Type, Name);
            declare
               Key : constant String := Key_Of (Prefix, Target_Type, Name);
            begin
               if Object.Contexts.Contains (Key) then
                  declare
                     Stored : constant Context_Maps.Constant_Reference_Type :=
                       Object.Contexts.Constant_Reference (Key);
                  begin
                     Charge_Context_Copy (Budget, Stored.Element.Value);
                     return
                       (Found => True,
                        Name_Index => Index,
                        Context => Stored.Element.Value);
                  end;
               end if;
            end;
         end;
      end loop;
      return (Found => False);
   end Load_Deepest_Context;

   procedure Remember_Context
     (Object : in out Cache;
      Budget : in out Budgets.Budget;
      Storage : aliased in out
        Giflib_Tooling.Validation_Storage_Budgets.Budget;
      Prefix : String;
      Target_Type : Identity.Target;
      Name : String;
      Context : Semantics.Type_Classification_Vectors.Vector) is
   begin
      Charge_Key (Budget, Prefix, Target_Type, Name);
      declare
         Key : constant String := Key_Of (Prefix, Target_Type, Name);
         Was_Full : constant Boolean :=
           Natural (Object.Context_Order.Length) >= Maximum_Contexts;
         Oldest : constant Unbounded_String :=
           (if Was_Full
            then Object.Context_Order.First_Element
            else Null_Unbounded_String);
      begin
         if Object.Contexts.Contains (Key) then
            return;
         end if;
         declare
            Measurement : constant Giflib_Tooling.Transition_Storage
              .Context_Measurement :=
                Giflib_Tooling.Transition_Storage.Measure_Context
                  (Key, Context);
            Retention :
              Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
                Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
         begin
            Budgets.Charge (Budget, Measurement.Copy_Work);
            Giflib_Tooling.Validation_Storage_Budgets.Charge
              (Retention, Measurement.Storage_Units);
            begin
               Object.Contexts.Insert
                 (Key,
                  (Value => Context,
                   Storage_Units => Measurement.Storage_Units));
               begin
                  Object.Context_Order.Append (To_Unbounded_String (Key));
               exception
                  when others =>
                     Object.Contexts.Delete (Key);
                     raise;
               end;
            end;
            Giflib_Tooling.Validation_Storage_Budgets.Commit (Retention);
            if Was_Full then
               declare
                  Old_Key : constant String := To_String (Oldest);
                  Old_Units : Natural;
               begin
                  declare
                     Old_Context : constant
                       Context_Maps.Constant_Reference_Type :=
                         Object.Contexts.Constant_Reference (Old_Key);
                  begin
                     Old_Units := Old_Context.Element.Storage_Units;
                  end;
                  Object.Contexts.Delete (Old_Key);
                  Object.Context_Order.Delete_First;
                  Giflib_Tooling.Validation_Storage_Budgets.Release_Retained
                    (Storage, Old_Units);
               end;
            end if;
         end;
      end;
   end Remember_Context;

end Giflib_Tooling.Transition_Context_Cache;
