with Ada.Strings.Unbounded;

package body Giflib_Tooling.Budgeted_Names is
   package Budgets renames Giflib_Tooling.Work_Budgets;
   function Contains
     (Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Name : String;
      Budget : in out Budgets.Budget) return Boolean is
   begin
      for Item of Names loop
         Budgets.Charge (Budget);
         if Ada.Strings.Unbounded.To_String (Item) = Name then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   procedure Include
     (Names : in out Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      Name : String;
      Budget : in out Budgets.Budget) is
   begin
      if not Contains (Names, Name, Budget) then
         Budgets.Charge (Budget);
         Names.Append (Ada.Strings.Unbounded.To_Unbounded_String (Name));
      end if;
   end Include;
end Giflib_Tooling.Budgeted_Names;
