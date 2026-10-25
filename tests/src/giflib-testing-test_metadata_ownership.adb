with AUnit.Assertions;
with Giflib.Errors;
with Giflib.Internal.Metadata_Store;
with Giflib.Internal.Ownership;
with Giflib.Internal.Ownership.Testing;
with Giflib.Metadata;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Metadata_Ownership is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;

   procedure Metadata_Store_Rejects_Foreign_Ledgers
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("metadata_ownership");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Metadata_Store_Rejects_Foreign_Ledgers'Access,
         "allocation_failures.metadata_owner_identity");
   end Register_Tests;

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
end Giflib.Testing.Test_Metadata_Ownership;
