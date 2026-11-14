with AUnit.Assertions;
with Ada.Assertions;
with System;

with Giflib.Errors;
with Giflib.Internal.Ownership;
with Giflib.Internal.Cleanup;
with Giflib.Internal.Resource_Cleanup;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Ownership_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Testing.Owned_Element_Vectors;
with Giflib.Internal.Owned_Objects;
with Giflib.Internal.Owned_Vectors;
with Giflib.Streams;

package body Giflib.Testing.Test_Ownership_Failures is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Ownership_Arithmetic.Injection_State;
   use type Giflib.Internal.Ownership.Allocation_Status;
   use type Giflib.Internal.Cleanup.Cleanup_Status;

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

   function Raise_On_Default return Integer is
   begin
      return (raise Constraint_Error with "raising default probe");
   end Raise_On_Default;

   type Raising_Test_Object is limited record
      Value : Integer := Raise_On_Default;
   end record
     with No_Controlled_Parts => True;
   package Raising_Objects is new Giflib.Internal.Owned_Objects
     (Raising_Test_Object);

   type Cleanup_Test_Element is limited record
      Value : Natural := 0;
      Releasable : Boolean := True;
      Cleanup_Succeeds : Boolean := True;
      Preflight_Raises : Boolean := False;
      Cleanup_Raises : Boolean := False;
   end record
     with No_Controlled_Parts => True;
   Released_Element_Contents : Natural := 0;

   function Can_Release_Element_Contents
     (Element : Cleanup_Test_Element;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget) return Boolean
   is
      pragma Unreferenced (Budget);
   begin
      if Element.Preflight_Raises then
         raise Program_Error with "preflight callback probe";
      end if;
      return Element.Releasable;
   end Can_Release_Element_Contents;

   function Release_Element_Contents
     (Element : in out Cleanup_Test_Element;
      Budget : aliased in out Giflib.Internal.Ownership.Byte_Budget)
      return Giflib.Internal.Cleanup.Cleanup_Outcome
   is
      pragma Unreferenced (Budget);
   begin
      Released_Element_Contents := Released_Element_Contents + 1;
      if Element.Cleanup_Raises then
         Element.Cleanup_Raises := False;
         raise Program_Error with "cleanup callback probe";
      end if;
      return
        (if Element.Cleanup_Succeeds
         then Giflib.Internal.Cleanup.Success
         else (Status => Giflib.Internal.Cleanup.Cleanup_Callback_Failed));
   end Release_Element_Contents;

   package Cleanup_Elements is new
     Giflib.Internal.Testing.Owned_Element_Vectors
     (Element_Type => Cleanup_Test_Element,
      Contents_Releasable => Can_Release_Element_Contents,
      Release_Contents => Release_Element_Contents);

   procedure Initialize_Cleanup_Element
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Value := 11;
   end Initialize_Cleanup_Element;

   procedure Block_Element_Release
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Releasable := False;
   end Block_Element_Release;

   procedure Allow_Element_Release
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Releasable := True;
   end Allow_Element_Release;

   procedure Report_Element_Cleanup_Failure
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Cleanup_Succeeds := False;
   end Report_Element_Cleanup_Failure;

   procedure Arm_Element_Preflight_Exception
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Preflight_Raises := True;
   end Arm_Element_Preflight_Exception;

   procedure Clear_Element_Preflight_Exception
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Preflight_Raises := False;
   end Clear_Element_Preflight_Exception;

   procedure Arm_Element_Cleanup_Exception
     (Value : in out Cleanup_Test_Element) is
   begin
      Value.Cleanup_Raises := True;
   end Arm_Element_Cleanup_Exception;

   procedure Ownership_Transitions_Are_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Failure_Injection_Is_Object_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raising_Initialization_Is_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Resources_Reject_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Array_Ranges_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Array_Growth_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Vector_Ownership_Is_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Scoped_Borrows_Block_Reentrant_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Element_Borrows_Block_Reentrant_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Element_Cleanup_Preflight_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Interrupted_Element_Cleanup_Is_Retryable
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Element_Cleanup_Outcomes_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Aggregate_Cleanup_Outcomes_Are_Preserved
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
        (T, Raising_Initialization_Is_Structured'Access,
         "allocation_failures.raising_initialization");
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
      Register_Routine
        (T, Scoped_Borrows_Block_Reentrant_Mutation'Access,
         "allocation_failures.scoped_borrow");
      Register_Routine
        (T, Element_Borrows_Block_Reentrant_Mutation'Access,
         "allocation_failures.element_borrow");
      Register_Routine
        (T, Element_Cleanup_Preflight_Is_Transactional'Access,
         "allocation_failures.element_preflight");
      Register_Routine
        (T, Interrupted_Element_Cleanup_Is_Retryable'Access,
         "allocation_failures.element_cleanup_retry");
      Register_Routine
        (T, Element_Cleanup_Outcomes_Are_Structured'Access,
         "allocation_failures.element_cleanup_outcome");
      Register_Routine
        (T, Aggregate_Cleanup_Outcomes_Are_Preserved'Access,
         "allocation_failures.aggregate_cleanup_outcome");
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

   procedure Scoped_Borrows_Block_Reentrant_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Element_Borrows_Block_Reentrant_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Element_Cleanup_Preflight_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Interrupted_Element_Cleanup_Is_Retryable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Element_Cleanup_Outcomes_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Aggregate_Cleanup_Outcomes_Are_Preserved
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Failure_Injection_Is_Object_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Raising_Initialization_Is_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Owned_Resources_Reject_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

end Giflib.Testing.Test_Ownership_Failures;
