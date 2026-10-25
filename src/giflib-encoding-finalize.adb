separate (Giflib.Encoding)
procedure Finalize (Object : in out Encoder) is
begin
   Resource_Management.Release (Object);
   if not Resource_Management.Cleanup_Succeeded (Object)
     and then Object.Diagnostic.Code = Errors.No_Error
   then
      Session_Transitions.Record_Diagnostic
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Session_Transitions.Finalize_Session (Object);
end Finalize;
