with AUnit.Assertions;
with System;

with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Decoding.Testing;
with Giflib.Encoding.Testing;
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
with Giflib.Internal.Quantization_Storage;
with Giflib.Internal.Quantization_Storage.Operations;
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
   use type Giflib.Internal.Quantization_Storage.Operations.Operation_Status;

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
   procedure Owned_Array_Ranges_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Array_Growth_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Owned_Vector_Ownership_Is_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Workspace_Failures_Are_Structured
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
        (T, Owned_Array_Ranges_Are_Structured'Access,
         "allocation_failures.array_range");
      Register_Routine
        (T, Owned_Array_Growth_Is_Transactional'Access,
         "allocation_failures.array_growth");
      Register_Routine
        (T, Owned_Vector_Ownership_Is_Exact'Access,
         "allocation_failures.vector_ownership");
      Register_Routine
        (T, Workspace_Failures_Are_Structured'Access,
         "allocation_failures.workspace_status");
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
      Rollback_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Rollback_Fault : Giflib.Internal.Ownership.Fault_State;
      Rollback_Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
      Reserved : Boolean;
      Work : Giflib.Internal.Work_Budgets.Meter (6);
      Accepted : Boolean;
      Work_Context : Giflib.Errors.Diagnostic_Context;
      Cleanup_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Cleanup_Failed : aliased Boolean := False;
      Residual_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Residual_Failed : aliased Boolean := False;
      function Raising_Release return Boolean is
      begin
         raise Program_Error;
         return True;
      end Raising_Release;
      procedure Attempt_Raising_Release is new
        Giflib.Internal.Resource_Cleanup.Attempt (Raising_Release);
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
      Assert
        (Giflib.Internal.Ownership.Release (Budget, 6)
         and then Giflib.Internal.Ownership.Used (Budget) = 0,
              "allocation budget release is unbalanced");
      Assert
        (not Giflib.Internal.Ownership.Release (Budget, 1)
         and then not Giflib.Internal.Ownership.Healthy (Budget),
         "ledger underflow did not leave a sticky cleanup fault");
      declare
         Ticket : Giflib.Internal.Ownership.Reservation
           (Rollback_Budget'Access);
      begin
         Rollback_Outcome := Giflib.Internal.Ownership.Reserve
           (Ticket, Rollback_Fault, 4, 4);
         Assert
           (Rollback_Outcome.Status =
              Giflib.Internal.Ownership.Allocation_Ready,
            "rollback test reservation failed");
         Giflib.Internal.Ownership.Testing.Set_Used (Rollback_Budget, 0);
      end;
      Assert
        (not Giflib.Internal.Ownership.Healthy (Rollback_Budget),
         "reservation finalizer discarded its rollback failure");
      Giflib.Internal.Work_Budgets.Try_Charge
        (Work, Amount => 6, Accepted => Accepted);
      Assert
        (Accepted
         and then Giflib.Internal.Work_Budgets.Used (Work) = 6
         and then Giflib.Internal.Work_Budgets.Attempted (Work) = 6,
         "shared work meter did not update its total");
      Giflib.Internal.Work_Budgets.Try_Charge
        (Work, Amount => 1, Accepted => Accepted);
      Assert
        (not Accepted
         and then Giflib.Internal.Work_Budgets.Used (Work) = 6
         and then Giflib.Internal.Work_Budgets.Attempted (Work) = 7
         and then Giflib.Internal.Work_Budgets.Failed (Work),
         "shared work-meter rejection changed its total");
      Giflib.Internal.Work_Budgets.Try_Charge
        (Work, Amount => 0, Accepted => Accepted);
      Assert
        (not Accepted
         and then Giflib.Internal.Work_Budgets.Used (Work) = 6
         and then Giflib.Internal.Work_Budgets.Attempted (Work) = 7,
         "exhausted work meter resumed or lost its first failure");
      Work_Context := Giflib.Internal.Resource_Diagnostics.With_Work_Limit
        (Work, Giflib.Optimization_Work_Limit);
      Assert
        (Work_Context.Expected = 6
         and then Work_Context.Actual = 7
         and then Work_Context.Limit = Giflib.Optimization_Work_Limit,
         "shared work-meter diagnostic context is wrong");
      declare
         Guard : Giflib.Internal.Resource_Cleanup.Guard
           (Cleanup_Budget'Access, Cleanup_Failed'Access);
      begin
         Attempt_Raising_Release (Guard);
         Assert
           (not Cleanup_Failed,
            "cleanup guard reconciled before leaving its scope");
      end;
      Assert
        (Cleanup_Failed,
         "scope-bound cleanup did not retain a release exception");
      Giflib.Internal.Ownership.Try_Reserve
        (Residual_Budget, 1, 1, Reserved);
      declare
         Guard : Giflib.Internal.Resource_Cleanup.Guard
           (Residual_Budget'Access, Residual_Failed'Access);
         pragma Unreferenced (Guard);
      begin
         null;
      end;
      Assert
        (Reserved and then Residual_Failed,
         "cleanup guard accepted a healthy ledger with residual ownership");
      Assert
        (Giflib.Internal.Ownership.Release (Residual_Budget, 1),
         "residual-ledger test cleanup failed");
   end Ownership_Transitions_Are_Exact;

   procedure Owned_Array_Ranges_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Object : Test_Array_Ownership.Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
      Item : Giflib.Errors.Error;
   begin
      Outcome := Test_Array_Ownership.Ensure
        (Object,
         Budget,
         Fault,
         First => 0,
         Last => Natural'Last,
         Maximum => Giflib.Byte_Count'Last);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Size_Error
         and then not Test_Array_Ownership.Is_Allocated (Object)
         and then Giflib.Internal.Ownership.Used (Budget) = 0,
         "unrepresentable array range did not return a structured failure");
      Item := Giflib.Internal.Resource_Diagnostics.Allocation_Error
        (Outcome, Giflib.Byte_Count'Last, Outcome.Attempted);
      Assert
        (Item.Code = Giflib.Errors.Integer_Overflow,
         "array range failure was translated incorrectly");
   end Owned_Array_Ranges_Are_Structured;

   procedure Owned_Array_Growth_Is_Transactional
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Object : Test_Array_Ownership.Handle;
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
      Before : Giflib.Byte_Count;
   begin
      Outcome := Test_Array_Ownership.Ensure
        (Object, Budget, Fault, First => 0, Last => 1, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
         and then Test_Array_Ownership.Element (Object, 0) = 0
         and then Test_Array_Ownership.Element (Object, 1) = 0,
         "owned-array allocation exposed uninitialized capacity");
      Test_Array_Ownership.Set_Element (Object, 0, 7);
      Before := Giflib.Internal.Ownership.Used (Budget);
      Giflib.Internal.Ownership.Testing.Arm (Fault);
      Outcome := Test_Array_Ownership.Ensure
        (Object, Budget, Fault, First => 0, Last => 3, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Storage_Error
         and then Test_Array_Ownership.Length (Object) = 2
         and then Test_Array_Ownership.Element (Object, 0) = 7
         and then Giflib.Internal.Ownership.Used (Budget) = Before,
         "failed owned-array replacement changed storage or its ledger");
      Outcome := Test_Array_Ownership.Grow
        (Object, Budget, Fault, First => 0, Last => 3,
         Preserve => 1, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
         and then Test_Array_Ownership.Element (Object, 0) = 7
         and then Test_Array_Ownership.Element (Object, 1) = 0
         and then Test_Array_Ownership.Element (Object, 3) = 0,
         "owned-array growth did not initialize unused capacity");
      Assert
        (Test_Array_Ownership.Release (Object, Budget),
         "owned-array initialized-capacity cleanup failed");
   end Owned_Array_Growth_Is_Transactional;

   procedure Owned_Vector_Ownership_Is_Exact
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Foreign_Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
      Vector : Test_Vector.Handle;
   begin
      Outcome := Test_Vector.Ensure_Append
        (Vector, Budget, Fault, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
         and then Test_Vector.Length (Vector) = 0
         and then Test_Vector.Capacity (Vector) = 2,
         "owned vector confused reserved capacity with logical length");
      Test_Vector.Append (Vector, 11);
      Test_Vector.Append (Vector, 12);
      Outcome := Test_Vector.Ensure_Append
        (Vector, Budget, Fault, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready
         and then Test_Vector.Length (Vector) = 2
         and then Test_Vector.Capacity (Vector) = 4
         and then Test_Vector.Element (Vector, 1) = 11
         and then Test_Vector.Element (Vector, 2) = 12,
         "owned vector growth changed its logical prefix");
      Test_Vector.Append (Vector, 13);
      Assert
        (Test_Vector.Length (Vector) = 3
         and then Test_Vector.Element (Vector, 3) = 13,
         "owned vector append did not advance logical length");
      Outcome := Test_Vector.Ensure_Append
        (Vector, Foreign_Budget, Fault, Maximum => 64);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Owner_Error
         and then Test_Vector.Length (Vector) = 3
         and then Giflib.Internal.Ownership.Used (Foreign_Budget) = 0,
         "owned vector accepted a foreign ledger through spare capacity");
      Assert
        (not Test_Vector.Release (Vector, Foreign_Budget)
         and then Test_Vector.Length (Vector) = 3
         and then Test_Vector.Element (Vector, 3) = 13,
         "foreign-ledger vector release changed logical contents");
      Assert
        (Test_Vector.Release (Vector, Budget)
         and then Test_Vector.Length (Vector) = 0,
         "owned vector cleanup did not reset logical length");
   end Owned_Vector_Ownership_Is_Exact;

   procedure Workspace_Failures_Are_Structured
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      package Storage renames Giflib.Internal.Quantization_Storage;
      package Operations renames Storage.Operations;
      Object : Storage.Resources;
      Fault : Giflib.Internal.Ownership.Fault_State;
      Outcome : Giflib.Internal.Ownership.Allocation_Outcome;
      Missing_Work : Giflib.Internal.Work_Budgets.Meter (100_000);
      Exhausted_Work : Giflib.Internal.Work_Budgets.Meter (0);
      Status : Operations.Operation_Status;
   begin
      Status := Operations.Reset_Histogram (Object, Missing_Work);
      Assert
        (Status = Operations.Operation_Invariant_Failure
         and then not Giflib.Internal.Work_Budgets.Failed (Missing_Work),
         "missing quantization storage was reported as work exhaustion");
      Outcome := Storage.Ensure_Nearest_Cache
        (Object, Fault, Giflib.Byte_Count'Last);
      Assert
        (Outcome.Status = Giflib.Internal.Ownership.Allocation_Ready,
         "nearest-cache setup failed");
      Status := Operations.Reset_Nearest_Cache (Object, Exhausted_Work);
      Assert
        (Status = Operations.Operation_Work_Limit
         and then Giflib.Internal.Work_Budgets.Failed (Exhausted_Work),
         "workspace work exhaustion was not recorded structurally");
      Storage.Release (Object);
      Assert
        (Storage.Cleanup_Succeeded (Object),
         "workspace status test cleanup failed");
   end Workspace_Failures_Are_Structured;

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
         others => <>);
      Data : constant Giflib.Streams.Byte_Array := [1 => 16#41#];
      Stored_Info : Giflib.Metadata.Extension_Info;
      Copied : Giflib.Streams.Byte_Array (1 .. 1);
      Copied_Count : Giflib.Byte_Count;
      Outcome : Giflib.Results.Result;
   begin
      Outcome := Store.Append
        (Object,
         Data,
         Giflib.Byte_Count'Last,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "metadata append accepted an idle store");
      Outcome := Store.Finish (Object, Info);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "metadata finish accepted an idle store");

      Outcome := Store.Start
        (Object,
         Giflib.Metadata.Retain_All_Bounded,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault,
         Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata store setup failed");
      Outcome := Store.Start
        (Object,
         Giflib.Metadata.Retain_All_Bounded,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault,
         Info);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_State,
              "metadata start replaced an unfinished extension");
      Outcome := Store.Append
        (Object,
         Data,
         Giflib.Byte_Count'Last,
         Giflib.Byte_Count'Last,
         Second_Budget,
         Fault);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Internal_Invariant_Failed
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "metadata store accepted a foreign ledger");
      Assert
        (not Store.Release (Object, Second_Budget)
         and then not Store.Is_Released (Object)
         and then Giflib.Internal.Ownership.Used (First_Budget) > 0
         and then Giflib.Internal.Ownership.Used (Second_Budget) = 0,
         "foreign-ledger metadata cleanup changed storage or a ledger");
      Assert
        (Store.Release (Object, First_Budget)
         and then Store.Is_Released (Object)
         and then Giflib.Internal.Ownership.Used (First_Budget) = 0,
         "metadata cleanup was not retryable with its owner");

      Outcome := Store.Start
        (Object,
         Giflib.Metadata.Retain_All_Bounded,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault,
         Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata cleanup-fault setup failed");
      Outcome := Store.Append
        (Object,
         Data,
         Giflib.Byte_Count'Last,
         Giflib.Byte_Count'Last,
         First_Budget,
         Fault);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata cleanup-fault payload setup failed");
      Outcome := Store.Finish (Object, Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata store finish failed");
      Outcome := Store.Info_At (Object, 1, Stored_Info);
      Assert (Giflib.Results.Succeeded (Outcome),
              "metadata store info lookup failed");
      Outcome := Store.Copy_Payload (Object, 1, Copied, Copied_Count);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then Stored_Info.Payload_Length = 1
         and then Copied_Count = 1
         and then Copied (1) = Data (1),
         "metadata store trusted a stale caller payload length");
      Giflib.Internal.Ownership.Testing.Set_Used (First_Budget, 0);
      Assert
        (not Store.Release (Object, First_Budget)
         and then Store.Is_Released (Object),
         "metadata store retained allocations after a ledger mismatch");
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
