with Giflib_Tooling.Source_Units;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Transition_Context_Cache;
with Giflib_Tooling.Transition_Storage;
with Giflib_Tooling.Work_Budgets;
with Giflib_Tooling.Validation_Storage_Budgets;

package body Giflib_Tooling.Transition_Context_Cache_Tests is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Session_Types.Type_Classification_Vectors.Vector;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Caches renames Giflib_Tooling.Transition_Context_Cache;
   package Budgets renames Giflib_Tooling.Work_Budgets;

   procedure Run is
      procedure Check_Context_Cache is
         Object : Caches.Cache;
         Budget : Budgets.Budget;
         Storage : aliased Giflib_Tooling.Validation_Storage_Budgets.Budget
           (Natural'Last);
         Target : constant Caches.Identity.Target :=
           Caches.Identity.Create_Known ("decoder", "giflib.decoding.decoder");
         Context : Caches.Semantics.Type_Classification_Vectors.Vector;
         Deep_Context : Caches.Semantics.Type_Classification_Vectors.Vector;
         Names : Caches.Names.Name_Vectors.Vector;
      begin
         Context.Append
           (Caches.Semantics.Type_Classification'
              (Kind => Caches.Semantics.Package_Relation,
               Name => To_Unbounded_String ("alias"),
               Target_Scope => To_Unbounded_String ("giflib.decoding")));
         Deep_Context := Context;
         Deep_Context.Append
           (Caches.Semantics.Type_Classification'
              (Kind => Caches.Semantics.Package_Relation,
               Name => To_Unbounded_String ("nested"),
               Target_Scope => To_Unbounded_String ("giflib.decoding.child")));
         Caches.Remember_Context
           (Object, Budget, Storage,
            "giflib-decoding", Target, "shared", Context);
         Caches.Remember_Context
           (Object, Budget, Storage,
            "giflib-decoding", Target, "child", Deep_Context);
         Check.Check
           (Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) =
              Giflib_Tooling.Transition_Storage.Measure_Context
                ("giflib-decoding:decoder:giflib.decoding.decoder:shared",
                 Context).Storage_Units +
              Giflib_Tooling.Transition_Storage.Measure_Context
                ("giflib-decoding:decoder:giflib.decoding.decoder:child",
                 Deep_Context).Storage_Units,
            "context cache charges its shared measurement schema exactly");
         Names.Append (To_Unbounded_String ("shared"));
         Names.Append (To_Unbounded_String ("child"));
         declare
            Loaded : constant Caches.Context_Lookup :=
              Caches.Load_Deepest_Context
                (Object, Budget, "giflib-decoding", Target, Names);
         begin
            Check.Check
              (Loaded.Found
               and then Loaded.Name_Index = 2
               and then Loaded.Context = Deep_Context,
               "context cache selects its deepest stored context");
         end;
      end Check_Context_Cache;

      procedure Check_Context_Eviction is
         Object : Caches.Cache;
         Budget : Budgets.Budget;
         Storage : aliased Giflib_Tooling.Validation_Storage_Budgets.Budget
           (Natural'Last);
         Target : constant Caches.Identity.Target :=
           Caches.Identity.Create_Known ("d", "d");
         Empty : Caches.Semantics.Type_Classification_Vectors.Vector;
         Used_Before_Eviction : Natural := 0;
         Expected_After_Eviction : Natural := 0;
         function Is_Cached (Name : String) return Boolean is
            Names : Caches.Names.Name_Vectors.Vector;
         begin
            Names.Append (To_Unbounded_String (Name));
            declare
               Loaded : constant Caches.Context_Lookup :=
                 Caches.Load_Deepest_Context
                   (Object, Budget, "p", Target, Names);
            begin
               return Loaded.Found
                 and then Loaded.Name_Index = Names.First_Index;
            end;
         end Is_Cached;
      begin
         for Index in 1 .. Caches.Maximum_Contexts loop
            Caches.Remember_Context
              (Object, Budget, Storage,
               "p", Target, Natural'Image (Index), Empty);
         end loop;
         Used_Before_Eviction :=
           Giflib_Tooling.Validation_Storage_Budgets.Used (Storage);
         declare
            Old_Key : constant String :=
              "p:d:d:" & Natural'Image (1);
            New_Key : constant String :=
              "p:d:d:" & Natural'Image (Caches.Maximum_Contexts + 1);
         begin
            Expected_After_Eviction := Used_Before_Eviction -
              Giflib_Tooling.Transition_Storage.Measure_Context
                (Old_Key, Empty).Storage_Units +
              Giflib_Tooling.Transition_Storage.Measure_Context
                (New_Key, Empty).Storage_Units;
         end;
         Caches.Remember_Context
           (Object, Budget, Storage,
            "p", Target, Natural'Image (Caches.Maximum_Contexts + 1), Empty);
         Check.Check
           (not Is_Cached (Natural'Image (1))
            and then Is_Cached (Natural'Image (Caches.Maximum_Contexts + 1))
            and then
              Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) =
                Expected_After_Eviction,
            "context cache evicts its oldest entry and releases its storage");
      end Check_Context_Eviction;

      procedure Check_Context_Budget is
         Object : Caches.Cache;
         Budget : Budgets.Budget (10);
         Verification_Budget : Budgets.Budget;
         Storage : aliased Giflib_Tooling.Validation_Storage_Budgets.Budget
           (Natural'Last);
         Target : constant Caches.Identity.Target :=
           Caches.Identity.Create_Known ("d", "d");
         Context : Caches.Semantics.Type_Classification_Vectors.Vector;
         Names : Caches.Names.Name_Vectors.Vector;
         Rejected : Boolean := False;
      begin
         Context.Append
           (Caches.Semantics.Type_Classification'
              (Kind => Caches.Semantics.Package_Relation,
               Name => To_Unbounded_String ("long-name"),
               Target_Scope => To_Unbounded_String ("long-target")));
         begin
            Caches.Remember_Context
              (Object, Budget, Storage, "p", Target, "k", Context);
         exception
            when Budgets.Work_Limit_Exceeded =>
               Rejected := True;
         end;
         Names.Append (To_Unbounded_String ("k"));
         declare
            Loaded : constant Caches.Context_Lookup :=
              Caches.Load_Deepest_Context
                (Object, Verification_Budget, "p", Target, Names);
         begin
            Check.Check
              (Rejected and then not Loaded.Found,
               "context cache charges nested storage before insertion");
         end;
      end Check_Context_Budget;

      procedure Check_Context_Storage_Budget is
         Object : Caches.Cache;
         Budget : Budgets.Budget;
         Storage : aliased
           Giflib_Tooling.Validation_Storage_Budgets.Budget (0);
         Target : constant Caches.Identity.Target :=
           Caches.Identity.Create_Known ("d", "d");
         Empty : Caches.Semantics.Type_Classification_Vectors.Vector;
         Clause_Rejected : Boolean := False;
         Context_Rejected : Boolean := False;
      begin
         begin
            Caches.Remember_Clause
              (Object, Budget, Storage, "unit",
               (Kind => Giflib_Tooling.Source_Units.No_Separate_Clause));
         exception
            when Giflib_Tooling.Validation_Storage_Budgets.Limit_Exceeded =>
               Clause_Rejected := True;
         end;
         begin
            Caches.Remember_Context
              (Object, Budget, Storage, "p", Target, "unit", Empty);
         exception
            when Giflib_Tooling.Validation_Storage_Budgets.Limit_Exceeded =>
               Context_Rejected := True;
         end;
         Check.Check
           (Clause_Rejected and then Context_Rejected
            and then not Caches.Contains_Clause (Object, "unit"),
            "retained transition caches share the validation storage budget");
      end Check_Context_Storage_Budget;

      procedure Check_Storage_Transactions is
         Storage : aliased
           Giflib_Tooling.Validation_Storage_Budgets.Budget (10);
         Provisional_Release_Rejected : Boolean := False;
      begin
         declare
            Retention :
              Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
                Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
         begin
            Giflib_Tooling.Validation_Storage_Budgets.Charge (Retention, 4);
         end;
         Check.Check
           (Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) = 0,
            "uncommitted storage transactions roll back automatically");
         declare
            Retention :
              Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
                Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
         begin
            Giflib_Tooling.Validation_Storage_Budgets.Charge (Retention, 1);
            begin
               Giflib_Tooling.Validation_Storage_Budgets.Release_Retained
                 (Storage, 1);
            exception
               when Program_Error =>
                  Provisional_Release_Rejected := True;
            end;
         end;
         Check.Check
           (Provisional_Release_Rejected
            and then
              Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) = 0,
            "retained release cannot undermine provisional rollback");
         declare
            Build : Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
              Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
            Item : Giflib_Tooling.Validation_Storage_Budgets.Transaction :=
              Giflib_Tooling.Validation_Storage_Budgets.Start (Storage);
         begin
            Giflib_Tooling.Validation_Storage_Budgets.Charge (Item, 3);
            Giflib_Tooling.Validation_Storage_Budgets.Transfer (Item, Build);
            Giflib_Tooling.Validation_Storage_Budgets.Charge (Build, 2);
            Giflib_Tooling.Validation_Storage_Budgets.Commit (Build);
         end;
         Check.Check
           (Giflib_Tooling.Validation_Storage_Budgets.Used (Storage) = 5,
            "nested storage transactions transfer and commit exactly");
      end Check_Storage_Transactions;

      procedure Check_Key_Budget is
         Object : Caches.Cache;
         Budget : Budgets.Budget (0);
         Target : constant Caches.Identity.Target :=
           Caches.Identity.Create_Known ("d", "d");
         Names : Caches.Names.Name_Vectors.Vector;
         Rejected : Boolean := False;
      begin
         Names.Append (To_Unbounded_String ("unit"));
         begin
            declare
               Loaded : constant Caches.Context_Lookup :=
                 Caches.Load_Deepest_Context
                   (Object, Budget, "p", Target, Names);
               pragma Unreferenced (Loaded);
            begin
               null;
            end;
         exception
            when Budgets.Work_Limit_Exceeded =>
               Rejected := True;
         end;
         Check.Check
           (Rejected, "context cache charges a key before lookup");
      end Check_Key_Budget;

   begin
      Check_Context_Cache;
      Check_Context_Eviction;
      Check_Context_Budget;
      Check_Context_Storage_Budget;
      Check_Storage_Transactions;
      Check_Key_Budget;
   end Run;
end Giflib_Tooling.Transition_Context_Cache_Tests;
