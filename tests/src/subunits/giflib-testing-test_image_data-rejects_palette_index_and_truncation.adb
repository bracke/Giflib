separate (Giflib.Testing.Test_Image_Data)
procedure Rejects_Palette_Index_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   --  Clear, literal 2, End. Literal 2 is outside a two-entry palette.
   Bad_Index : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#54#, 16#01#, 0];
   Truncated : aliased constant Giflib.Streams.Byte_Array := [2, 2, 16#44#];
   Source : Giflib.Streams.Memory_Source (Bad_Index'Access);
   Truncated_Source : Giflib.Streams.Memory_Source (Truncated'Access);
   Context : Giflib.Internal.LZW.Workspace_Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Output : Giflib.Streams.Byte_Array (1 .. 2);
   Pixels : Giflib.Pixel_Count := 0;
   Compressed : Giflib.Byte_Count := 0;
   Outcome : Giflib.Results.Result;
begin
   Prepare (Context, Budget, Fault);
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Source, 1, 2, False, Two_Color_Palette,
      Giflib.Limits.Default_Limits,
      Pixels, Compressed, Output (1 .. 1), Frame => 7);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch,
           "wrong-sized target was not rejected before input");
   Assert (Source.Offset = 0, "wrong-sized target consumed input");

   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Source, 1, 1, False, Two_Color_Palette,
      Giflib.Limits.Default_Limits,
      Pixels, Compressed, Output (1 .. 1), Frame => 7);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Palette_Index_Out_Of_Range,
           "invalid palette index was accepted");
   Assert (Outcome.First_Error.Context.Frame.Present
           and then Outcome.First_Error.Context.Frame.Value = 7,
           "palette error lost frame context");

   Pixels := 0;
   Compressed := 0;
   Giflib.Streams.Open (Truncated_Source);
   Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Truncated_Source, 1, 2, False, Two_Color_Palette,
      Giflib.Limits.Default_Limits,
      Pixels, Compressed, Output);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block,
           "truncated compressed sub-block has wrong error");
   Assert (Giflib.Internal.Cleanup.Succeeded
             (Giflib.Internal.LZW.Release (Context, Budget)),
           "malformed-image LZW workspace ledger mismatch");
end Rejects_Palette_Index_And_Truncation;
