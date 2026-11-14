with Ada.Strings.Unbounded;

package body Giflib_Tooling.Transition_Storage is
   use Ada.Strings.Unbounded;
   package Storage_Budgets renames
     Giflib_Tooling.Validation_Storage_Budgets;
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Units;
   use type Source.Separate_Clause_Kind;

   Container_Element_Units : constant := 1;
   Map_Node_Units : constant := 1;
   Stored_Field_Units : constant := 1;

   function Text_Units (Length : Natural) return Natural is
     (Stored_Field_Units + Length);

   function Name_Units (Name : String) return Natural is
     (Container_Element_Units + Name'Length);

   function Clause_Data_Units
     (Clause : Source.Separate_Clause) return Natural is
     (Stored_Field_Units +
        (if Clause.Kind = Source.Valid_Separate_Clause
         then Text_Units (Length (Clause.Parent)) else 0));

   function Map_Entry_Units (Key : String) return Natural is
     (Map_Node_Units + Stored_Field_Units + Text_Units (Key'Length));

   function Indexed_Unit_Units
     (Name : String;
      Path : String;
      Clause : Source.Separate_Clause) return Natural is
     (Container_Element_Units + 6 * Stored_Field_Units + Name'Length +
      Path'Length + Clause_Data_Units (Clause) + Map_Entry_Units (Name));

   function Clause_Units
     (Name : String; Clause : Source.Separate_Clause) return Natural is
     (Map_Entry_Units (Name) + Clause_Data_Units (Clause));

   procedure Charge_Name
     (Storage : in out Storage_Budgets.Transaction; Name : String) is
   begin
      Storage_Budgets.Charge (Storage, Name_Units (Name));
   end Charge_Name;

   procedure Charge_Indexed_Unit
     (Storage : in out Storage_Budgets.Transaction;
      Name : String;
      Path : String;
      Clause : Source.Separate_Clause) is
   begin
      Storage_Budgets.Charge
        (Storage, Indexed_Unit_Units (Name, Path, Clause));
   end Charge_Indexed_Unit;

   procedure Charge_Clause
     (Storage : in out Storage_Budgets.Transaction;
      Name : String;
      Clause : Source.Separate_Clause) is
   begin
      Storage_Budgets.Charge (Storage, Clause_Units (Name, Clause));
   end Charge_Clause;

   procedure Measure_Context_Item
     (Result : in out Context_Measurement;
      Item : Semantics.Type_Classification) is
      procedure Measure_Text (Length : Natural) is
      begin
         Result.Copy_Work := Result.Copy_Work + Length;
         Result.Storage_Units := Result.Storage_Units + Text_Units (Length);
      end Measure_Text;
   begin
      Result.Copy_Work := Result.Copy_Work + 1;
      Result.Storage_Units :=
        Result.Storage_Units + Container_Element_Units;
      Measure_Text (Length (Item.Name));
      case Item.Kind is
         when Semantics.Type_Relation =>
            Measure_Text (Length (Item.Type_Data.Declared_Type));
            Measure_Text (Length (Item.Related_Type));
         when Semantics.Component_Relation =>
            Measure_Text (Length (Item.Component_Data.Declared_Type));
            Measure_Text (Length (Item.Owner_Type));
         when Semantics.Callable_Relation =>
            Measure_Text (Length (Item.Callable_Data.Declared_Type));
            Measure_Text (Length (Item.Scope_Name));
            Measure_Text (Length (Item.Profile.Text));
            for Formal of Item.Profile.Formal_Types loop
               Result.Copy_Work := Result.Copy_Work + 1;
               Result.Storage_Units :=
                 Result.Storage_Units + Container_Element_Units;
               Measure_Text (Length (Formal));
            end loop;
         when Semantics.Package_Relation =>
            Measure_Text (Length (Item.Target_Scope));
      end case;
   end Measure_Context_Item;

   function Measure_Context
     (Key : String;
      Context : Semantics.Type_Classification_Vectors.Vector)
      return Context_Measurement is
   begin
      return Result : Context_Measurement :=
        (Copy_Work => 0,
         Storage_Units => Map_Entry_Units (Key) +
           Stored_Field_Units + Container_Element_Units +
           Text_Units (Key'Length))
      do
         for Item of Context loop
            Measure_Context_Item (Result, Item);
         end loop;
      end return;
   end Measure_Context;

end Giflib_Tooling.Transition_Storage;
