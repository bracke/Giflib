with Giflib.Decoding.Lifecycle_Sequence;

separate (Giflib.Decoding)
procedure Finalize (Object : in out Decoder) is
begin
   Lifecycle_Sequence.Finalize_Session (Object);
end Finalize;
