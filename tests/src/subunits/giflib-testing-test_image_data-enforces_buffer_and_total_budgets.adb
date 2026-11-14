separate (Giflib.Testing.Test_Image_Data)
procedure Enforces_Buffer_And_Total_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#, 16#0A#, 0];
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Context : Giflib.Internal.LZW.Workspace_Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Output : Giflib.Streams.Byte_Array (1 .. 2);
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Pixels : Giflib.Pixel_Count := 1;
   Compressed : Giflib.Byte_Count := 0;
   Outcome : Giflib.Results.Result;
begin
   Prepare (Context, Budget, Fault);
   Constraints.Max_Total_Decoded_Frame_Pixels := 2;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Source, 1, 2, False, Two_Color_Palette, Constraints,
      Pixels, Compressed, Output);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "total decoded pixel budget was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Total_Decoded_Pixel_Limit,
           "pixel budget failure lost context");
   Assert (Source.Offset = 0, "pixel budget failure consumed input");

   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Compressed_Bytes := 1;
   Pixels := 0;
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Source, 1, 2, False, Two_Color_Palette, Constraints,
      Pixels, Compressed, Output);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "compressed byte budget was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Compressed_Byte_Limit,
           "compressed byte failure lost context");
   Assert (Giflib.Internal.Cleanup.Succeeded
             (Giflib.Internal.LZW.Release (Context, Budget)),
           "budgeted-image LZW workspace ledger mismatch");
end Enforces_Buffer_And_Total_Budgets;
