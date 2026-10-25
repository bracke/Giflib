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
with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Quantization_Storage.Dither_Operations;
with Giflib.Internal.Quantization_Storage.Histogram_Operations;
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

   procedure Workspace_Failures_Are_Structured
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
