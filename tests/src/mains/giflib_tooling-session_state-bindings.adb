with Giflib_Tooling.Session_State.Scopes;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Session_State.Bindings is
   package Scopes renames Giflib_Tooling.Session_State.Scopes;
   package Text_Case renames Giflib_Tooling.Text_Case;
   use Scopes;

   procedure Append_Binding
     (Object : in out State;
      Item : Binding;
      Budget : in out Budgets.Budget)
   is
      Value : Binding := Item;
      Binding_Depth : constant Natural :=
        (if Item.Kind = Component_Binding and then Depth (Object) > 0
         then Depth (Object) - 1 else Depth (Object));
      Index_Work : constant Natural :=
        Name_Of (Item)'Length + 2 +
        (if Item.Kind = Component_Binding
         then To_String (Item.Data.Component_Info.Owner_Type)'Length + 1
         else 0);
   begin
      Budgets.Charge_Scan (Budget, Index_Work);
      Value.Scope_Depth := Binding_Depth;
      Object.Bindings.Append (Value);
      Index_Binding (Object, Object.Bindings.Last_Index);
   end Append_Binding;

   procedure Bind_Object
     (Object : in out State;
      Name : Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Budget : in out Budgets.Budget;
      Declared_Type : String := "") is
   begin
      Append_Binding
        (Object,
         (Kind => Object_Binding, Scope_Depth => 0,
          Prior_Name => (Present => False),
          Data =>
            (Kind => Object_Binding, Object_Name => Name,
             Object_Relation =>
               (Depth => Session_Nesting,
                Declared_Type => To_Unbounded_String (Declared_Type),
                Related_Type => Null_Unbounded_String))),
         Budget);
   end Bind_Object;

   procedure Append_Package_Binding
     (Object : in out State;
      Name : Unbounded_String;
      Target : Unbounded_String;
      Resolution : Package_Resolution;
      Budget : in out Budgets.Budget) is
   begin
      Append_Binding
        (Object,
         (Kind => Package_Binding, Scope_Depth => 0,
          Prior_Name => (Present => False),
          Data =>
            (Kind => Package_Binding,
             Package_Info =>
               (Kind => Semantics.Package_Relation,
                Name => Name,
                Target_Scope => Target),
             Resolution => Resolution)),
         Budget);
   end Append_Package_Binding;

   procedure Add_Implicit_Package_Binding
     (Object : in out State;
      Name : String;
      Target : String;
      Budget : in out Budgets.Budget)
   is
      Alias_Name : constant String := Text_Case.Lower (Name);
      Scope_Name : constant String := Text_Case.Lower (Target);
      Current_Depth : constant Natural := Depth (Object);
      Index : Optional_Binding_Index :=
        Latest_Name_Index (Object, Alias_Name);

      procedure Append_Alias (Resolution : Package_Resolution) is
      begin
         Append_Package_Binding
           (Object,
            To_Unbounded_String (Alias_Name),
            (if Resolution = Ambiguous_Target
             then Null_Unbounded_String
             else To_Unbounded_String (Scope_Name)),
            Resolution, Budget);
      end Append_Alias;
   begin
      while Index.Present loop
         declare
            Cursor : constant Positive := Index.Value;
            Kind : constant Binding_Kind := Object.Bindings (Cursor).Kind;
            Scope_Depth : constant Natural :=
              Object.Bindings (Cursor).Scope_Depth;
            Prior : constant Optional_Binding_Index :=
              Object.Bindings (Cursor).Prior_Name;
            Is_Final_Package : constant Boolean :=
              Kind = Package_Binding
              and then Object.Bindings (Cursor).Data.Resolution in
                Explicit_Target | Ambiguous_Target;
            Is_Same_Implicit : constant Boolean :=
              Kind = Package_Binding
              and then Object.Bindings (Cursor).Data.Resolution =
                Implicit_Target
              and then To_String
                (Object.Bindings (Cursor).Data.Package_Info.Target_Scope) =
                  Scope_Name;
         begin
            if Kind /= Component_Binding and then Scope_Depth < Current_Depth
            then
               exit;
            elsif Scope_Depth = Current_Depth then
               if Kind /= Package_Binding
                 or else Is_Final_Package
                 or else Is_Same_Implicit
               then
                  return;
               end if;
               Append_Alias (Ambiguous_Target);
               return;
            end if;
            Index := Prior;
         end;
      end loop;
      Append_Alias (Implicit_Target);
   end Add_Implicit_Package_Binding;

   procedure Bind_Classification
     (Object : in out State;
      Item : Semantics.Type_Classification;
      Budget : in out Budgets.Budget) is
   begin
      case Item.Kind is
         when Semantics.Type_Relation =>
            Append_Binding
              (Object,
               (Kind => Type_Binding, Scope_Depth => 0,
                Prior_Name => (Present => False),
                Data => (Kind => Type_Binding, Type_Info => Item)),
               Budget);
         when Semantics.Component_Relation =>
            Append_Binding
              (Object,
               (Kind => Component_Binding, Scope_Depth => 0,
                Prior_Name => (Present => False),
                Prior_Component => (Present => False),
                Data => (Kind => Component_Binding, Component_Info => Item)),
               Budget);
         when Semantics.Callable_Relation =>
            Append_Binding
              (Object,
               (Kind => Callable_Binding, Scope_Depth => 0,
                Prior_Name => (Present => False),
                Data => (Kind => Callable_Binding, Callable_Info => Item)),
               Budget);
         when Semantics.Package_Relation =>
            Append_Package_Binding
              (Object, Item.Name, Item.Target_Scope, Explicit_Target, Budget);
      end case;
   end Bind_Classification;

   procedure Bind_Type
     (Object : in out State;
      Name : Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Budget : in out Budgets.Budget;
      Related_Type : String := "") is
   begin
      Bind_Classification
        (Object,
         (Kind => Semantics.Type_Relation, Name => Name,
          Type_Data =>
            (Session_Nesting, To_Unbounded_String (Declared_Type)),
          Related_Type => To_Unbounded_String (Related_Type)),
         Budget);
   end Bind_Type;

   procedure Bind_Component
     (Object : in out State;
      Name : Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Owner_Type : String;
      Budget : in out Budgets.Budget) is
   begin
      Bind_Classification
        (Object,
         (Kind => Semantics.Component_Relation, Name => Name,
          Component_Data =>
            (Session_Nesting, To_Unbounded_String (Declared_Type)),
          Owner_Type => To_Unbounded_String (Owner_Type)),
         Budget);
   end Bind_Component;

   procedure Bind_Callable
     (Object : in out State;
      Name : Unbounded_String;
      Session_Nesting : Semantics.Session_Depth;
      Declared_Type : String;
      Callable_Scope : String;
      Callable_Profile : Semantics.Callable_Profile;
      Budget : in out Budgets.Budget) is
   begin
      Bind_Classification
        (Object,
         (Kind => Semantics.Callable_Relation, Name => Name,
          Callable_Data =>
            (Session_Nesting, To_Unbounded_String (Declared_Type)),
          Scope_Name => To_Unbounded_String (Callable_Scope),
          Profile => Callable_Profile),
         Budget);
   end Bind_Callable;

   procedure Bind_Package
     (Object : in out State;
      Name : String;
      Budget : in out Budgets.Budget;
      Target : String := "") is
   begin
      Bind_Classification
        (Object,
         (Kind => Semantics.Package_Relation,
          Name => To_Unbounded_String (Text_Case.Lower (Name)),
          Target_Scope =>
            To_Unbounded_String
              (Text_Case.Lower ((if Target = "" then Name else Target)))),
         Budget);
   end Bind_Package;

end Giflib_Tooling.Session_State.Bindings;
