with AUnit.Assertions;
with System;

with Giflib.Errors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Resource_Cleanup;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Ownership_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Owned_Objects;
with Giflib.Internal.Owned_Vectors;

package body Giflib.Testing.Test_Ownership_Failures is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Ownership_Arithmetic.Injection_State;
   use type Giflib.Internal.Ownership.Allocation_Status;

   type Test_Array is array (Natural range <>) of Integer;
   package Test_Array_Ownership is new Giflib.Internal.Owned_Arrays
     (Natural, Integer, Test_Array, 0);
   type Test_Vector_Array is array (Positive range <>) of Integer;
   package Test_Vector_Storage is new Giflib.Internal.Owned_Arrays
     (Positive, Integer, Test_Vector_Array, 0);
   package Test_Vector is new Giflib.Internal.Owned_Vectors
     (Element_Type => Integer,
      Storage => Test_Vector_Storage,
      Initial_Capacity => 2);

   procedure Ownership_Transitions_Are_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Failure_Injection_Is_Object_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Resources_Reject_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Array_Ranges_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Array_Growth_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Vector_Ownership_Is_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("ownership_failures");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Ownership_Transitions_Are_Exact'Access,
         "allocation_failures.ownership_arithmetic");
      Register_Routine
        (T, Failure_Injection_Is_Object_Local'Access,
         "allocation_failures.object_local_injection");
      Register_Routine
        (T, Owned_Resources_Reject_Foreign_Ledgers'Access,
         "allocation_failures.owner_identity");
      Register_Routine
        (T, Owned_Array_Ranges_Are_Structured'Access,
         "allocation_failures.array_range");
      Register_Routine
        (T, Owned_Array_Growth_Is_Transactional'Access,
         "allocation_failures.array_growth");
      Register_Routine
        (T, Owned_Vector_Ownership_Is_Exact'Access,
         "allocation_failures.vector_ownership");
   end Register_Tests;

   procedure Ownership_Transitions_Are_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Owned_Array_Ranges_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Owned_Array_Growth_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Owned_Vector_Ownership_Is_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

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

   procedure Owned_Resources_Reject_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Buffers renames Giflib.Internal.Owned_Buffers;
      type Test_Object is limited record
         Value : Giflib.Byte := 0;
      end record;
      package Objects is new Giflib.Internal.Owned_Objects (Test_Object);
      Buffer : Buffers.Handle;
      Object : Objects.Handle;
      First_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Second_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
   begin
      Outcome := Buffers.Ensure
        (Buffer, First_Budget, Fault, Required => 8, Maximum => 8);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "owned buffer setup failed");
      Outcome := Buffers.Ensure
        (Buffer, Second_Budget, Fault, Required => 8, Maximum => 8);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
         and then Buffers.Is_Allocated (Buffer)
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "owned buffer accepted a foreign ledger");
      Assert
        (not Buffers.Release (Buffer, Second_Budget)
         and then Buffers.Is_Allocated (Buffer)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 8
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "foreign-ledger cleanup changed storage or a ledger");
      Assert
        (Buffers.Release (Buffer, First_Budget)
         and then not Buffers.Is_Allocated (Buffer)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
         "owned buffer cleanup was not retryable with its owner");

      Outcome := Buffers.Ensure
        (Buffer, First_Budget, Fault, Required => 8, Maximum => 8);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "owned buffer cleanup-fault setup failed");
      Giflib.Internal.Ownership.Testing.Set_Used (First_Budget, 0);
      Assert
        (not Buffers.Release (Buffer, First_Budget)
         and then not Buffers.Is_Allocated (Buffer),
         "owned buffer retained storage after a ledger mismatch");
      Giflib.Internal.Ownership.Testing.Set_Used (First_Budget, 0);

      Outcome := Objects.Ensure
        (Object,
         First_Budget,
         Fault,
         Maximum => Objects.Allocation_Bytes);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "owned object setup failed");
      Outcome := Objects.Ensure
        (Object,
         Second_Budget,
         Fault,
         Maximum => Objects.Allocation_Bytes);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
         and then Objects.Is_Allocated (Object),
         "owned object accepted a foreign ledger");
      Assert
        (not Objects.Release (Object, Second_Budget)
         and then Objects.Is_Allocated (Object)
         and then Giflib.Internal.Ownership.Used (First_Budget)
           = Objects.Allocation_Bytes
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "foreign-ledger object cleanup changed storage or a ledger");
      Assert
        (Objects.Release (Object, First_Budget)
         and then not Objects.Is_Allocated (Object)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
         "owned object cleanup was not retryable with its owner");
   end Owned_Resources_Reject_Foreign_Ledgers;

end Giflib.Testing.Test_Ownership_Failures;
