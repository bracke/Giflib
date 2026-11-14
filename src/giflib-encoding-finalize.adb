with Giflib.Encoding.Lifecycle_Sequence;

separate (Giflib.Encoding)
procedure Finalize (Object : in out Encoder) is
begin
   Lifecycle_Sequence.Finalize_Session (Object);
end Finalize;
