package body Giflib_Tooling.Session_State is

   function Component_Key (Owner_Type : String; Name : String) return String is
     (Owner_Type & Character'Val (0) & Name);

   function Indexed_Name_Count (Object : State) return Natural is
     (Natural (Object.Name_Indices.Length));

   function Indexed_Binding_Count (Object : State) return Natural is
     (Natural (Object.Bindings.Length));

   procedure Index_Binding (Object : in out State; Index : Positive) is
      Item : Binding renames Object.Bindings (Index);
      Name : constant String := Name_Of (Item);
   begin
      Item.Prior_Name := Latest_Name_Index (Object, Name);
      Object.Name_Indices.Include (Name, Index);
      if Item.Kind = Component_Binding then
         declare
            Key : constant String :=
              Component_Key
                (To_String (Item.Data.Component_Info.Owner_Type), Name);
         begin
            Item.Prior_Component :=
              Latest_Component_Index
                (Object,
                 To_String (Item.Data.Component_Info.Owner_Type), Name);
            Object.Component_Indices.Include (Key, Index);
         end;
      end if;
   end Index_Binding;

   function Unindex_Binding
     (Object : in out State; Index : Positive) return Boolean
   is
      Item : Binding renames Object.Bindings (Index);
      Name : constant String := Name_Of (Item);
      Latest_Name : constant Optional_Binding_Index :=
        Latest_Name_Index (Object, Name);
   begin
      if not Latest_Name.Present or else Latest_Name.Value /= Index then
         return False;
      end if;
      if Item.Kind = Component_Binding then
         declare
            Latest_Component : constant Optional_Binding_Index :=
              Latest_Component_Index
                (Object,
                 To_String (Item.Data.Component_Info.Owner_Type), Name);
         begin
            if not Latest_Component.Present
              or else Latest_Component.Value /= Index
            then
               return False;
            end if;
         end;
      end if;
      if not Item.Prior_Name.Present then
         Object.Name_Indices.Delete (Name);
      else
         Object.Name_Indices.Replace (Name, Item.Prior_Name.Value);
      end if;
      if Item.Kind = Component_Binding then
         declare
            Key : constant String := Component_Key
              (To_String (Item.Data.Component_Info.Owner_Type), Name);
         begin
            if not Item.Prior_Component.Present then
               Object.Component_Indices.Delete (Key);
            else
               Object.Component_Indices.Replace
                 (Key, Item.Prior_Component.Value);
            end if;
         end;
      end if;
      return True;
   end Unindex_Binding;

   function Latest_Name_Index
     (Object : State; Name : String) return Optional_Binding_Index is
     (if Object.Name_Indices.Contains (Name)
      then (Present => True, Value => Object.Name_Indices.Element (Name))
      else (Present => False));

   function Latest_Component_Index
     (Object : State; Owner_Type : String; Name : String)
      return Optional_Binding_Index
   is
      Key : constant String := Component_Key (Owner_Type, Name);
   begin
      return
        (if Object.Component_Indices.Contains (Key)
         then
           (Present => True, Value => Object.Component_Indices.Element (Key))
         else (Present => False));
   end Latest_Component_Index;

   function Name_Candidate_Count
     (Object : State;
      Name : String;
      Budget : in out Budgets.Budget) return Natural
   is
      Index : Optional_Binding_Index := Latest_Name_Index (Object, Name);
      Count : Natural := 0;
   begin
      while Index.Present loop
         Budgets.Charge (Budget);
         Count := Count + 1;
         Index := Object.Bindings (Index.Value).Prior_Name;
      end loop;
      return Count;
   end Name_Candidate_Count;

   function Component_Candidate_Count
     (Object : State;
      Owner_Type : String;
      Name : String;
      Budget : in out Budgets.Budget) return Natural
   is
      Index : Optional_Binding_Index :=
        Latest_Component_Index (Object, Owner_Type, Name);
      Count : Natural := 0;
   begin
      while Index.Present loop
         Budgets.Charge (Budget);
         Count := Count + 1;
         Index := Object.Bindings (Index.Value).Prior_Component;
      end loop;
      return Count;
   end Component_Candidate_Count;

   function Name_Of (Item : Binding) return String is
   begin
      case Item.Kind is
         when Object_Binding =>
            return To_String (Item.Data.Object_Name);
         when Type_Binding =>
            return To_String (Item.Data.Type_Info.Name);
         when Component_Binding =>
            return To_String (Item.Data.Component_Info.Name);
         when Callable_Binding =>
            return To_String (Item.Data.Callable_Info.Name);
         when Package_Binding =>
            return To_String (Item.Data.Package_Info.Name);
      end case;
   end Name_Of;

   function Relation_Of (Item : Binding) return Relation is
   begin
      case Item.Kind is
         when Object_Binding =>
            return Item.Data.Object_Relation;
         when Type_Binding =>
            return Semantics.Relation_Of (Item.Data.Type_Info);
         when Component_Binding =>
            return Semantics.Relation_Of (Item.Data.Component_Info);
         when Callable_Binding =>
            return Semantics.Relation_Of (Item.Data.Callable_Info);
         when Package_Binding =>
            return (others => <>);
      end case;
   end Relation_Of;

end Giflib_Tooling.Session_State;
