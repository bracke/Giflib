package body Giflib.Internal.Lifecycle_Protocol is
   use type Giflib.Errors.Error_Code;
   use type Giflib.Internal.Cleanup.Cleanup_Status;

   function Cleanup_Succeeded
     (Object : Session;
      Outcome : Giflib.Internal.Cleanup.Cleanup_Outcome) return Boolean is
     (Giflib.Internal.Cleanup.Succeeded (Outcome)
      and then First_Cleanup_Status (Object) =
        Giflib.Internal.Cleanup.Cleanup_Complete);

   procedure Commit_Cleanup_Failure (Object : in out Session) is
   begin
      Commit_Failure
        (Object, Giflib.Errors.Make (Giflib.Errors.Internal_Invariant_Failed));
   end Commit_Cleanup_Failure;

   function Prepare_Initialization
     (Object : in out Session) return Giflib.Results.Result
   is
      Outcome : constant Giflib.Internal.Cleanup.Cleanup_Outcome :=
        Release (Object);
   begin
      if not Cleanup_Succeeded (Object, Outcome) then
         Commit_Cleanup_Failure (Object);
         return Giflib.Results.Failure (First_Error (Object));
      end if;
      return Giflib.Results.Success;
   end Prepare_Initialization;

   function Release_And_Cancel
     (Object : in out Session) return Giflib.Results.Result
   is
      Outcome : constant Giflib.Internal.Cleanup.Cleanup_Outcome :=
        Release (Object);
   begin
      if not Cleanup_Succeeded (Object, Outcome) then
         Commit_Cleanup_Failure (Object);
         return Giflib.Results.Failure (First_Error (Object));
      end if;
      Commit_Cancel (Object);
      return Giflib.Results.Success;
   end Release_And_Cancel;

   procedure Finalize_Session (Object : in out Session) is
      Outcome : constant Giflib.Internal.Cleanup.Cleanup_Outcome :=
        Release (Object);
   begin
      if not Cleanup_Succeeded (Object, Outcome)
        and then First_Error (Object).Code = Giflib.Errors.No_Error
      then
         Record_Diagnostic
           (Object,
            Giflib.Errors.Make (Giflib.Errors.Internal_Invariant_Failed));
      end if;
      Commit_Finalize (Object);
   end Finalize_Session;
end Giflib.Internal.Lifecycle_Protocol;
