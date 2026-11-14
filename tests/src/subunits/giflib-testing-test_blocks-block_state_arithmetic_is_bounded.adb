separate (Giflib.Testing.Test_Blocks)
procedure Block_State_Arithmetic_Is_Bounded
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Block_Arithmetic;
   Read_Plan : constant Arithmetic.Reader_Transfer :=
     Arithmetic.Plan_Read (Remaining => 255, Requested => 17);
   Fill_Plan : constant Arithmetic.Writer_Transfer :=
     Arithmetic.Plan_Write (Used => 254, Position => 0, Length => Natural'Last);
   Tail_Plan : constant Arithmetic.Writer_Transfer :=
     Arithmetic.Plan_Write (Used => 10, Position => 90, Length => 100);
begin
   Assert
     (Read_Plan.Count = 17 and then Read_Plan.Remaining = 238,
      "reader transfer state is wrong");
   Assert
     (Fill_Plan.Count = 1
      and then Fill_Plan.Used = 255
      and then Fill_Plan.Position = 1,
      "full-block writer transition is wrong");
   Assert
     (Tail_Plan.Count = 10
      and then Tail_Plan.Used = 20
      and then Tail_Plan.Position = 100,
      "final writer transition is wrong");
end Block_State_Arithmetic_Is_Bounded;
