package body Giflib_Tooling.Model_Storage is
   use Ada.Strings.Unbounded;
   package Budgets renames Giflib_Tooling.Model_Storage_Budgets;
   package Source_Events renames Giflib_Tooling.Source_Events;
   package Source_Tokens renames Giflib_Tooling.Source_Tokens;
   package Source_Units renames Giflib_Tooling.Source_Units;
   use type Source_Units.Separate_Clause_Kind;

   procedure Charge_Model (Storage : in out Budgets.Budget) is
   begin
      --  Token, program-unit, event, and separate-clause containers.
      Budgets.Charge (Storage, 4);
   end Charge_Model;

   function Saturated_Natural (Value : Long_Long_Integer) return Natural is
     (Natural
        (Long_Long_Integer'Min
           (Long_Long_Integer (Natural'Last), Value)));

   function Item_Units
     (First_Length : Natural; Second_Length : Natural := 0) return Natural is
     (Saturated_Natural
        (1 + Long_Long_Integer (First_Length)
         + Long_Long_Integer (Second_Length)));

   procedure Charge_Item
     (Storage : in out Budgets.Budget;
      First_Length : Natural := 0;
      Second_Length : Natural := 0) is
   begin
      Budgets.Charge
        (Storage, Item_Units (First_Length, Second_Length));
   end Charge_Item;

   procedure Charge_Token
     (Storage : in out Budgets.Budget; Text_Length : Natural) is
   begin
      Charge_Item (Storage, Text_Length);
   end Charge_Token;

   procedure Charge_Program_Unit
     (Storage : in out Budgets.Budget;
      Name : Unbounded_String;
      Profile : Unbounded_String) is
   begin
      Charge_Item (Storage, Length (Name), Length (Profile));
   end Charge_Program_Unit;

   procedure Charge_Terminal_Event (Storage : in out Budgets.Budget) is
   begin
      Charge_Item (Storage);
   end Charge_Terminal_Event;

   procedure Charge_Named_Event
     (Storage : in out Budgets.Budget; Name : Unbounded_String) is
   begin
      Charge_Item (Storage, Length (Name));
   end Charge_Named_Event;

   procedure Charge_Subprogram_Event
     (Storage : in out Budgets.Budget;
      Name : Unbounded_String;
      Profile : Unbounded_String) is
   begin
      Charge_Item (Storage, Length (Name), Length (Profile));
   end Charge_Subprogram_Event;

   procedure Charge_Separate_Clause
     (Storage : in out Budgets.Budget; Parent_Length : Natural) is
   begin
      Budgets.Charge (Storage, Parent_Length);
   end Charge_Separate_Clause;

   function Measure
     (Tokens : Source_Tokens.Token_Vectors.Vector;
      Units : Source_Units.Program_Unit_Vectors.Vector;
      Events : Source_Events.Structural_Event_Vectors.Vector;
      Clause : Source_Units.Separate_Clause) return Natural
   is
      Total : Long_Long_Integer := 4;
      procedure Add (Amount : Natural) is
      begin
         Total := Long_Long_Integer'Min
           (Long_Long_Integer (Natural'Last),
            Total + Long_Long_Integer (Amount));
      end Add;
   begin
      for Item of Tokens loop
         Add (Item_Units (Length (Source_Tokens.Text_Of (Item))));
      end loop;
      for Item of Units loop
         Add (Item_Units (Length (Item.Name), Length (Item.Profile)));
      end loop;
      for Item of Events loop
         case Item.Kind is
            when Source_Events.Subprogram_Start =>
               Add
                 (Item_Units
                    (Length (Item.Subprogram_Name),
                     Length (Item.Header.Profile)));
            when Source_Events.Package_Start =>
               Add (Item_Units (Length (Item.Package_Name)));
            when Source_Events.Program_Start =>
               Add (Item_Units (Length (Item.Program_Name)));
            when Source_Events.Block_Start =>
               Add (Item_Units (Length (Item.Block_Name)));
            when Source_Events.Record_Start =>
               Add (Item_Units (Length (Item.Record_Name)));
            when Source_Events.Scope_End =>
               Add (Item_Units (Length (Item.Ending_Name)));
            when Source_Events.No_Structural_Event |
                 Source_Events.Record_End |
                 Source_Events.Loop_End |
                 Source_Events.Return_End |
                 Source_Events.Control_End =>
               Add (Item_Units (0));
         end case;
      end loop;
      if Clause.Kind = Source_Units.Valid_Separate_Clause then
         Add (Length (Clause.Parent));
      end if;
      return Saturated_Natural (Total);
   end Measure;
end Giflib_Tooling.Model_Storage;
