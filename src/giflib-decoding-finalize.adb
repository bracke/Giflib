separate (Giflib.Decoding)
procedure Finalize (Object : in out Decoder) is
begin
   Resource_Management.Release (Object);
   if not Internal.Decoder_Storage.Cleanup_Succeeded (Object.Resources)
     and then Object.Diagnostic.Code = Errors.No_Error
   then
      Session_Transitions.Record_Diagnostic
        (Object, Errors.Make (Errors.Internal_Invariant_Failed));
   end if;
   Session_Transitions.Finalize_Session (Object);
end Finalize;
