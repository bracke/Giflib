package body Giflib_Tooling.Session_Types is
   function "<" (Left : Session_Depth; Right : Session_Depth) return Boolean is
     (Left.Present
      and then
        (not Right.Present or else Left.Level < Right.Level));

   function "<=" (Left : Session_Depth; Right : Session_Depth) return Boolean is
     (Left = Right or else Left < Right);

   function Nested (Item : Session_Depth) return Session_Depth is
     (if not Item.Present or else Item.Level = Natural'Last
      then No_Session_Depth
      else (Present => True, Level => Item.Level + 1));

   function Element (Item : Session_Depth) return Session_Depth is
     (if not Item.Present or else Item.Level = 0
      then No_Session_Depth
      else (Present => True, Level => Item.Level - 1));

   function Relation_Of (Item : Type_Classification) return Relation is
   begin
      case Item.Kind is
         when Type_Relation =>
            return
              (Item.Type_Data.Depth, Item.Type_Data.Declared_Type,
               Item.Related_Type);
         when Component_Relation =>
            return
              (Item.Component_Data.Depth,
               Item.Component_Data.Declared_Type,
               Ada.Strings.Unbounded.Null_Unbounded_String);
         when Callable_Relation =>
            return
              (Item.Callable_Data.Depth,
               Item.Callable_Data.Declared_Type,
               Ada.Strings.Unbounded.Null_Unbounded_String);
         when Package_Relation =>
            return (others => <>);
      end case;
   end Relation_Of;
end Giflib_Tooling.Session_Types;
