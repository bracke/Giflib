separate (Giflib.Decoding)
procedure Finalize (Object : in out Decoder) is
   Cleanup_Outcome : constant Internal.Cleanup.Cleanup_Outcome :=
     Resource_Management.Release (Object);
begin
   if not Internal.Cleanup.Succeeded (Cleanup_Outcome)
     and then Object.Diagnostic.Code = Errors.No_Error
   then
      Session_Transitions.Record_Diagnostic
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Session_Transitions.Finalize_Session (Object);
end Finalize;
