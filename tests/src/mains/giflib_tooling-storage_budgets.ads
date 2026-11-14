with Ada.Finalization;

private generic
package Giflib_Tooling.Storage_Budgets is
   Limit_Exceeded : exception;

   type Budget (Limit : Natural) is limited private;
   type Transaction (<>) is limited private;

   procedure Charge (Object : in out Budget; Amount : Natural := 1);
   procedure Release_Retained
     (Object : in out Budget; Amount : Natural := 1);
   function Used (Object : Budget) return Natural;
   function Start (Object : aliased in out Budget) return Transaction;
   procedure Charge (Object : in out Transaction; Amount : Natural := 1);
   procedure Commit (Object : in out Transaction);
   procedure Transfer
     (Object : in out Transaction; Target : in out Transaction);
private
   type Budget (Limit : Natural) is limited record
      Retained : Natural := 0;
      Provisional : Natural := 0;
      Next_Transaction_Id : Natural := 0;
      Valid : Boolean := True;
   end record;
   type Transaction (Owner : not null access Budget) is
     new Ada.Finalization.Limited_Controlled with record
      Amount : Natural := 0;
      Id : Natural := 0;
      Active : Boolean := True;
   end record;
   overriding procedure Finalize (Object : in out Transaction);
end Giflib_Tooling.Storage_Budgets;
