separate (Giflib.Testing.Test_LZW_Encoding)
procedure Enforces_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [0, 1, 2, 3];
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 32 => 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Context : Giflib.Internal.LZW_Encoding.Testing.Workspace;
   Outcome : Giflib.Results.Result;
   Compressed : Giflib.Byte_Count;
begin
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
     (Context, Destination, Input, 2, 1, 100, 100, Compressed);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "LZW encoding work budget was ignored");

   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Internal.LZW_Encoding.Testing.Encode
     (Context, Destination, Input, 2, 1_000, 1, 100, Compressed);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "compressed output budget was ignored");
end Enforces_Encoding_Budgets;
