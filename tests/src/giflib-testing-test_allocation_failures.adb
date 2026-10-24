with AUnit.Assertions;
with System;

with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Decoding.Testing;
with Giflib.Encoding.Testing;
with Giflib.Internal.Ownership;
with Giflib.Internal.Ownership.Testing;
with Giflib.Internal.Ownership_Arithmetic;
with Giflib.Internal.Owned_Buffers;
with Giflib.Internal.Metadata_Store;
with Giflib.Metadata;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Quantization.Testing;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Allocation_Failures is
   use AUnit.Assertions;
   use type Giflib.Decoding.Decoder_State;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Encoding.Encoder_State;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Ownership_Arithmetic.Injection_State;
   use type Giflib.Internal.Ownership.Allocation_Status;

   procedure Decoder_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Quantizer_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Encoder_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Ownership_Transitions_Are_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Failure_Injection_Is_Object_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Resources_Reject_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Metadata_Store_Rejects_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("allocation_failures");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Decoder_Allocation_Failures'Access,
         "allocation_failures.decoder");
      Register_Routine
        (T, Quantizer_Allocation_Failures'Access,
         "allocation_failures.quantizer");
      Register_Routine
        (T, Encoder_Allocation_Failures'Access,
         "allocation_failures.encoder");
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
        (T, Metadata_Store_Rejects_Foreign_Ledgers'Access,
         "allocation_failures.metadata_owner_identity");
   end Register_Tests;

   procedure Ownership_Transitions_Are_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Ownership_Arithmetic;
      State : constant Arithmetic.Injection_State := Arithmetic.Arm (2);
      Result : Arithmetic.Check_Result;
      Budget : Giflib.Internal.Ownership.Byte_Budget;
      Reserved : Boolean;
   begin
      Result := Arithmetic.Check (State);
      Assert
        (not Result.Raise_Error
         and then Result.State.Enabled
         and then Result.State.Remaining_Successes = 1,
         "first injected allocation transition is wrong");
      Result := Arithmetic.Check (Result.State);
      Assert
        (not Result.Raise_Error
         and then Result.State.Enabled
         and then Result.State.Remaining_Successes = 0,
         "second injected allocation transition is wrong");
      Result := Arithmetic.Check (Result.State);
      Assert
        (Result.Raise_Error and then Result.State = Arithmetic.Disabled,
         "injected failure did not disable itself");
      Result := Arithmetic.Check (Result.State);
      Assert (not Result.Raise_Error and then Result.State = Arithmetic.Disabled,
              "disabled injection did not remain inert");
      Giflib.Internal.Ownership.Try_Reserve (Budget, 10, 6, Reserved);
      Assert
        (Giflib.Internal.Ownership.Storage_Bytes (System.Storage_Unit + 1) = 2
         and then Reserved,
         "allocation budget sizing or reservation is wrong");
      Giflib.Internal.Ownership.Try_Reserve (Budget, 10, 5, Reserved);
      Assert
        (Giflib.Internal.Ownership.Used (Budget) = 6
         and then not Reserved,
         "allocation budget did not retain its charge");
      Giflib.Internal.Ownership.Release (Budget, 6);
      Assert (Giflib.Internal.Ownership.Used (Budget) = 0,
              "allocation budget release is unbalanced");
   end Ownership_Transitions_Are_Exact;

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
      Buffer : Buffers.Handle;
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
         and then not Buffers.Release (Buffer, Second_Budget)
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "owned buffer accepted or debited a foreign ledger");
      Assert
        (Buffers.Release (Buffer, First_Budget)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
         "owned buffer did not release through its original ledger");
   end Owned_Resources_Reject_Foreign_Ledgers;

   procedure Metadata_Store_Rejects_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Store renames Giflib.Internal.Metadata_Store;
      Object : Store.Store;
      First_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Second_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Info : constant Giflib.Metadata.Extension_Info :=
        (Kind => Giflib.Metadata.Comment_Extension,
         Label => 16#FE#,
         others => <>);
      Data : constant Giflib.Streams.Byte_Array := [1 => 16#41#];
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Store.Start
        (Object,
         Giflib.Metadata.Retain_All_Bounded,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault,
         Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata store setup failed");
      Outcome := Store.Append
        (Object,
         Data,
         Giflib.Byte_Count'Last,
         Giflib.Byte_Count'Last,
         Second_Budget,
         Fault);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
         and then not Store.Release (Object, Second_Budget)
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "metadata store accepted or debited a foreign ledger");
      Store.Finish (Object, Info);
      Assert
        (Store.Release (Object, First_Budget)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
         "metadata store did not release through its original ledger");
   end Metadata_Store_Rejects_Foreign_Ledgers;

   procedure Require_Allocation_Failure
     (Outcome : Giflib.Results.Result;
      Message : String)
   is
   begin
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
         and then Outcome.First_Error.Context.Limit
           = Giflib.Allocation_Byte_Limit,
         Message);
   end Require_Allocation_Failure;

   procedure Decoder_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Quantizer_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Encoder_Allocation_Failures
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Allocation_Failures;
