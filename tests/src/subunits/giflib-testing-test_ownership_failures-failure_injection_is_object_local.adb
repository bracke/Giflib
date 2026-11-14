separate (Giflib.Testing.Test_Ownership_Failures)
procedure Failure_Injection_Is_Object_Local
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   First, Second : Giflib.Internal.Ownership.Fault_State;
   First_Raised : Boolean := False;
   Second_Raised : Boolean := False;
begin
   Giflib.Internal.Ownership.Testing.Arm (First);
   begin
      Giflib.Internal.Ownership.Check_Allocation (Second);
   exception
      when Storage_Error =>
         Second_Raised := True;
   end;
   begin
      Giflib.Internal.Ownership.Check_Allocation (First);
   exception
      when Storage_Error =>
         First_Raised := True;
   end;
   Assert
     (First_Raised and then not Second_Raised,
      "allocation failure injection crossed object boundaries");
end Failure_Injection_Is_Object_Local;

