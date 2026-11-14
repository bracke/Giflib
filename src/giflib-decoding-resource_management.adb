with Giflib.Internal.Diagnostics;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Decoding.Session_Transitions;

package body Giflib.Decoding.Resource_Management is
   use type Internal.Cleanup.Cleanup_Status;

   function Release
     (Resources : in out Decoder_Resources)
      return Internal.Cleanup.Cleanup_Outcome
   is (Internal.Decoder_Storage.Release (Resources));

   function Release
     (Object : in out Decoder) return Internal.Cleanup.Cleanup_Outcome
   is
      Current : constant Internal.Cleanup.Cleanup_Outcome :=
        Release (Object.Resources);
   begin
      Session_Transitions.Clear_Resource_State (Object);
      return
        (Status =>
           (if Internal.Decoder_Storage.First_Cleanup_Status
                 (Object.Resources) /= Internal.Cleanup.Cleanup_Complete
            then Internal.Decoder_Storage.First_Cleanup_Status
              (Object.Resources)
            else Current.Status));
   end Release;

   function Complete_Allocation
     (Object : Decoder;
      Allocation : Internal.Ownership.Allocation_Outcome;
      Include_Frame : Boolean := True)
      return Results.Result
   is
      Context : constant Errors.Diagnostic_Context :=
        Internal.Diagnostics.At_Source
          (Object.Input.all,
           (Frame =>
              (if Include_Frame
               then Errors.Frame_At (Object.Frames_Seen)
               else (Present => False)),
            others => <>));
   begin
      return Internal.Resource_Diagnostics.Allocation_Result
        (Allocation,
         Object.Constraints.Max_Allocation_Bytes,
         Allocation.Attempted,
         Context);
   end Complete_Allocation;

   function Ensure_Frame_Scratch
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Required > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Allocation := Internal.Decoder_Storage.Ensure_Frame_Scratch
        (Object.Resources,
         Object.Allocation_Fault,
         Required,
         Object.Constraints.Max_Allocation_Bytes);
      return Complete_Allocation (Object, Allocation);
   end Ensure_Frame_Scratch;

   function Ensure_LZW_Workspace
     (Object : in out Decoder) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      Allocation := Internal.Decoder_Storage.Ensure_LZW
        (Object.Resources,
         Object.Allocation_Fault,
         Object.Constraints.Max_Allocation_Bytes);
      return Complete_Allocation (Object, Allocation);
   end Ensure_LZW_Workspace;

   function Ensure_Snapshot
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Required > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Allocation := Internal.Decoder_Storage.Ensure_Snapshot
        (Object.Resources,
         Object.Allocation_Fault,
         Required,
         Object.Constraints.Max_Allocation_Bytes);
      return Complete_Allocation (Object, Allocation);
   end Ensure_Snapshot;

   function Ensure_Canvas
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result
   is
      Allocation : Internal.Ownership.Allocation_Outcome;
   begin
      if Required > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      end if;
      Allocation := Internal.Decoder_Storage.Ensure_Canvas
        (Object.Resources,
         Object.Allocation_Fault,
         Required,
         Object.Constraints.Max_Allocation_Bytes);
      return Complete_Allocation
        (Object, Allocation, Include_Frame => False);
   end Ensure_Canvas;

end Giflib.Decoding.Resource_Management;

