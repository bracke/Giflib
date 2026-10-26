separate (Giflib.Encoding)
procedure Finalize (Object : in out Encoder) is
   Cleanup_Status : constant Quantization.Cleanup_Status :=
     Resource_Management.Release (Object);
begin
   if Cleanup_Status /= Quantization.Cleanup_Complete
     and then Object.Diagnostic.Code = Errors.No_Error
   then
      Session_Transitions.Record_Diagnostic
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Session_Transitions.Finalize_Session (Object);
end Finalize;
