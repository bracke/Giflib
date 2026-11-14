package body Giflib_Tooling.Session_Contexts is
   use Ada.Strings.Unbounded;
   use Semantics;

   procedure Upsert
     (Context : in out Type_Classification_Vectors.Vector;
      Item : Type_Classification;
      Budget : in out Budgets.Budget)
   is
      Found : Boolean := False;
   begin
      for Index in reverse Context.First_Index .. Context.Last_Index loop
         Budgets.Charge (Budget);
         if Context (Index).Name = Item.Name then
            if Item.Kind /= Component_Relation
              and then Context (Index).Kind /= Component_Relation
              and then Context (Index).Kind /= Item.Kind
            then
               Budgets.Charge_Scan
                 (Budget, Context.Last_Index - Index);
               Context.Delete (Index);
            elsif not Found
              and then Context (Index).Kind = Item.Kind
              and then
                (case Item.Kind is
                    when Type_Relation => True,
                    when Component_Relation =>
                      Context (Index).Owner_Type = Item.Owner_Type,
                    when Callable_Relation =>
                      Context (Index).Scope_Name = Item.Scope_Name
                        and then Context (Index).Profile = Item.Profile,
                    when Package_Relation => True)
            then
               Context.Replace_Element (Index, Item);
               Found := True;
            end if;
         end if;
      end loop;
      if not Found then
         Budgets.Charge (Budget);
         Context.Append (Item);
      end if;
   end Upsert;

   procedure Set_Type
     (Context : in out Type_Classification_Vectors.Vector;
      Name : Unbounded_String;
      Depth : Session_Depth;
      Declared_Type : Unbounded_String;
      Related_Type : Unbounded_String;
      Budget : in out Budgets.Budget) is
   begin
      Upsert
        (Context,
         (Kind => Type_Relation, Name => Name,
          Type_Data => (Depth, Declared_Type),
          Related_Type => Related_Type), Budget);
   end Set_Type;

   procedure Set_Component
     (Context : in out Type_Classification_Vectors.Vector;
      Name : Unbounded_String;
      Depth : Session_Depth;
      Declared_Type : Unbounded_String;
      Owner_Type : Unbounded_String;
      Budget : in out Budgets.Budget) is
   begin
      Upsert
        (Context,
         (Kind => Component_Relation, Name => Name,
          Component_Data => (Depth, Declared_Type),
          Owner_Type => Owner_Type), Budget);
   end Set_Component;

   procedure Set_Callable
     (Context : in out Type_Classification_Vectors.Vector;
      Name : Unbounded_String;
      Depth : Session_Depth;
      Declared_Type : Unbounded_String;
      Scope_Name : Unbounded_String;
      Profile : Callable_Profile;
      Budget : in out Budgets.Budget) is
   begin
      Upsert
        (Context,
         (Kind => Callable_Relation, Name => Name,
          Callable_Data => (Depth, Declared_Type), Scope_Name => Scope_Name,
          Profile => Profile), Budget);
   end Set_Callable;

   procedure Set_Package
     (Context : in out Type_Classification_Vectors.Vector;
      Name : Unbounded_String;
      Target_Scope : Unbounded_String;
      Budget : in out Budgets.Budget) is
   begin
      Upsert
        (Context,
         (Kind => Package_Relation, Name => Name,
          Target_Scope => Target_Scope), Budget);
   end Set_Package;
end Giflib_Tooling.Session_Contexts;
