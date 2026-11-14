with Ada.Containers;

package body Giflib_Tooling.Session_State.Scopes is
   use type Ada.Containers.Count_Type;

   function Index_Work (Item : Binding) return Natural is
     (Name_Of (Item)'Length + 2
      + (if Item.Kind = Component_Binding
         then To_String (Item.Data.Component_Info.Owner_Type)'Length + 1
         else 0));

   procedure Charge_Rebuild
     (Object : State; Budget : in out Budgets.Budget)
   is
   begin
      if not Object.Bindings.Is_Empty then
         for Index in Object.Bindings.First_Index .. Object.Bindings.Last_Index - 1
         loop
            Budgets.Charge_Scan
              (Budget, Index_Work (Object.Bindings (Index)));
         end loop;
      end if;
   end Charge_Rebuild;

   procedure Rebuild_Indices
     (Object : in out State)
   is
   begin
      Object.Name_Indices.Clear;
      Object.Component_Indices.Clear;
      if not Object.Bindings.Is_Empty then
         declare
            Index : Positive := Object.Bindings.First_Index;
         begin
            loop
            declare
               Item : Binding := Object.Bindings (Index);
            begin
               Item.Prior_Name := (Present => False);
               if Item.Kind = Component_Binding then
                  Item.Prior_Component := (Present => False);
               end if;
               Object.Bindings.Replace_Element (Index, Item);
               Index_Binding (Object, Index);
            end;
               exit when Index = Object.Bindings.Last_Index;
               Index := Index + 1;
            end loop;
         end;
      end if;
   end Rebuild_Indices;

   procedure Push
     (Object : in out State; Kind : Scope_Kind; End_Name : String := "") is
   begin
      Object.Scopes.Append (Scope'(Kind, To_Unbounded_String (End_Name)));
      if Kind in Package_Scope | Program_Scope
        and then Object.Scopes.Length = 1
      then
         Object.Context_Depth := 1;
      end if;
   end Push;

   procedure Pop
     (Object : in out State; Budget : in out Budgets.Budget) is
      Old_Depth : constant Natural := Natural (Object.Scopes.Length);
   begin
      if Object.Scopes.Is_Empty then
         return;
      end if;
      while not Object.Bindings.Is_Empty
        and then Object.Bindings.Last_Element.Scope_Depth >= Old_Depth
      loop
         declare
            Index : constant Positive := Object.Bindings.Last_Index;
            Needs_Rebuild : Boolean;
         begin
            declare
               Item : Binding renames Object.Bindings (Index);
            begin
               Budgets.Charge_Scan (Budget, Index_Work (Item));
               Needs_Rebuild := not Unindex_Binding (Object, Index);
            end;
            if Needs_Rebuild then
               --  Reserve all recovery work before mutating the authoritative
               --  binding sequence or either derived index.
               Charge_Rebuild (Object, Budget);
            end if;
            Object.Bindings.Delete_Last;
            if Needs_Rebuild then
               --  Recover derived indexes from the authoritative binding
               --  sequence instead of leaving a half-popped scope.
               Rebuild_Indices (Object);
            end if;
         end;
      end loop;
      Object.Scopes.Delete_Last;
   end Pop;

   function Is_Empty (Object : State) return Boolean is
     (Object.Scopes.Is_Empty);

   function Depth (Object : State) return Natural is
     (Natural (Object.Scopes.Length));

   function Top_Is (Object : State; Kind : Scope_Kind) return Boolean is
     (not Object.Scopes.Is_Empty
      and then Object.Scopes.Last_Element.Kind = Kind);

   function Top_End_Name (Object : State) return String is
     (if Object.Scopes.Is_Empty then ""
      else To_String (Object.Scopes.Last_Element.End_Name));

   function Is_Context_Level (Object : State) return Boolean is
     (Depth (Object) = Object.Context_Depth);

   function Is_Context_Component_Level (Object : State) return Boolean is
     (Depth (Object) = Object.Context_Depth + 1
      and then not Is_Empty (Object)
      and then Top_Is (Object, Record_Scope));

end Giflib_Tooling.Session_State.Scopes;
