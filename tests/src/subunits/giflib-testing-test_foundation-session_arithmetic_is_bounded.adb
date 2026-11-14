separate (Giflib.Testing.Test_Foundation)
procedure Session_Arithmetic_Is_Bounded
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Session_Arithmetic;
   Budget : constant Giflib.Internal.Budget_Arithmetic.Charge_Result :=
     Giflib.Internal.Budget_Arithmetic.Charge
       (Giflib.Byte_Count'Last - 1, Giflib.Byte_Count'Last, 1);
   Overflow : constant Giflib.Internal.Budget_Arithmetic.Charge_Result :=
     Giflib.Internal.Budget_Arithmetic.Charge
       (Giflib.Byte_Count'Last, Giflib.Byte_Count'Last, 1);
begin
   Assert
     (Arithmetic.Has_Natural_Capacity
        (Natural'Last - 1, Natural'Last, 1),
      "session count capacity is wrong");
   Assert
     (Budget.Accepted
      and then Budget.Total = Giflib.Byte_Count'Last
      and then not Overflow.Accepted
      and then Overflow.Attempted = Giflib.Byte_Count'Last,
      "allocation accounting is wrong");
end Session_Arithmetic_Is_Bounded;

