package body Giflib_Tooling.Session_State.Visibility is
   use type Semantics.Session_Depth;

   type Scope_Lookup (Present : Boolean := False) is record
      case Present is
         when True =>
            Level : Natural;
         when False =>
            null;
      end case;
   end record;

   function Visible_Name_Scope
     (Object : State; Name : String) return Scope_Lookup
   is
      Index : Optional_Binding_Index := Latest_Name_Index (Object, Name);
   begin
      while Index.Present loop
         declare
            Cursor : constant Positive := Index.Value;
         begin
            if Object.Bindings (Cursor).Kind /= Component_Binding then
               return
                 (Present => True,
                  Level => Object.Bindings (Cursor).Scope_Depth);
            end if;
            Index := Object.Bindings (Cursor).Prior_Name;
         end;
      end loop;
      return (Present => False);
   end Visible_Name_Scope;

   function Visible_Depth
     (Object : State; Kind : Relation_Binding_Kind; Name : String)
      return Semantics.Session_Depth
   is
      Item : constant Relation := Visible_Relation (Object, Kind, Name);
   begin
      return Item.Depth;
   end Visible_Depth;

   function Visible_Sessions
     (Object : State) return Syntax.Name_Vectors.Vector
   is
      Result : Syntax.Name_Vectors.Vector;
      Cursor : Binding_Index_Maps.Cursor := Object.Name_Indices.First;
   begin
      while Binding_Index_Maps.Has_Element (Cursor) loop
         declare
            Name : constant String := Binding_Index_Maps.Key (Cursor);
            Index : Optional_Binding_Index :=
              (Present => True, Value => Binding_Index_Maps.Element (Cursor));
         begin
            while Index.Present loop
               declare
                  Position : constant Positive := Index.Value;
               begin
                  if Object.Bindings (Position).Kind /= Component_Binding then
                     if Object.Bindings (Position).Kind = Object_Binding
                       and then Relation_Of (Object.Bindings (Position)).Depth =
                         Semantics.Direct_Session
                     then
                        Result.Append (To_Unbounded_String (Name));
                     end if;
                     exit;
                  end if;
                  Index := Object.Bindings (Position).Prior_Name;
               end;
            end loop;
         end;
         Binding_Index_Maps.Next (Cursor);
      end loop;
      return Result;
   end Visible_Sessions;

   function Visible_Relation
     (Object : State; Kind : Relation_Binding_Kind; Name : String)
      return Relation
   is
      Scope : constant Scope_Lookup := Visible_Name_Scope (Object, Name);
      Index : Optional_Binding_Index := Latest_Name_Index (Object, Name);
   begin
      if not Scope.Present then
         return (others => <>);
      end if;
      while Index.Present loop
         declare
            Cursor : constant Positive := Index.Value;
         begin
            if Object.Bindings (Cursor).Scope_Depth = Scope.Level then
               if Object.Bindings (Cursor).Kind = Kind then
                  return Relation_Of (Object.Bindings (Cursor));
               elsif Object.Bindings (Cursor).Kind /= Component_Binding then
                  return (others => <>);
               end if;
            end if;
            Index := Object.Bindings (Cursor).Prior_Name;
         end;
      end loop;
      return (others => <>);
   end Visible_Relation;

   function Visible_Package
     (Object : State; Name : String) return Package_Lookup
   is
      Scope : constant Scope_Lookup := Visible_Name_Scope (Object, Name);
      Index : Optional_Binding_Index := Latest_Name_Index (Object, Name);
   begin
      if not Scope.Present then
         return (others => <>);
      end if;
      while Index.Present loop
         declare
            Cursor : constant Positive := Index.Value;
         begin
            if Object.Bindings (Cursor).Scope_Depth = Scope.Level then
               if Object.Bindings (Cursor).Kind /= Package_Binding then
                  return (others => <>);
               elsif Object.Bindings (Cursor).Data.Resolution =
                 Ambiguous_Target
               then
                  return
                    (Kind => Package_Ambiguous,
                     Target => Null_Unbounded_String);
               else
                  return
                    (Kind => Package_Found,
                     Target =>
                       Object.Bindings (Cursor).Data.Package_Info.Target_Scope);
               end if;
            end if;
            Index := Object.Bindings (Cursor).Prior_Name;
         end;
      end loop;
      return (others => <>);
   end Visible_Package;

   procedure Visit_Visible_Callables
     (Object : State;
      Name : String;
      Qualified : Boolean;
      Process : not null access procedure
        (Value : Relation;
         Scope_Name : String;
         Profile : Semantics.Callable_Profile;
         Scope_Depth : Natural;
         Continue : in out Boolean))
   is
      Scope : constant Scope_Lookup :=
        (if Qualified
         then (Present => False)
         else Visible_Name_Scope (Object, Name));
      Index : Optional_Binding_Index := Latest_Name_Index (Object, Name);
      Continue : Boolean := True;
   begin
      if not Qualified and then not Scope.Present then
         return;
      end if;
      while Index.Present and then Continue loop
         declare
            Cursor : constant Positive := Index.Value;
         begin
            if Object.Bindings (Cursor).Kind = Callable_Binding
              and then
                (Qualified
                 or else Object.Bindings (Cursor).Scope_Depth = Scope.Level)
            then
               Process
                 (Relation_Of (Object.Bindings (Cursor)),
                  To_String
                    (Object.Bindings (Cursor).Data.Callable_Info.Scope_Name),
                  Object.Bindings (Cursor).Data.Callable_Info.Profile,
                  Object.Bindings (Cursor).Scope_Depth,
                  Continue);
            end if;
            Index := Object.Bindings (Cursor).Prior_Name;
         end;
      end loop;
   end Visit_Visible_Callables;

   function Find_Component
     (Object : State; Owner_Type : String; Name : String) return Relation
   is
      Index : constant Optional_Binding_Index :=
        Latest_Component_Index (Object, Owner_Type, Name);
   begin
      if Index.Present then
         return Relation_Of (Object.Bindings (Index.Value));
      end if;
      return (others => <>);
   end Find_Component;

end Giflib_Tooling.Session_State.Visibility;
