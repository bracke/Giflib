separate (Giflib.Testing.Test_Image_Data)
procedure Decode_And_Skip_Share_Prefix_Diagnostics
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Invalid : aliased constant Giflib.Streams.Byte_Array := [1];
   Truncated : aliased constant Giflib.Streams.Byte_Array := [2];
   Decode_Source : Giflib.Streams.Memory_Source (Invalid'Access);
   Skip_Source : Giflib.Streams.Memory_Source (Invalid'Access);
   Truncated_Decode_Source : Giflib.Streams.Memory_Source (Truncated'Access);
   Truncated_Skip_Source : Giflib.Streams.Memory_Source (Truncated'Access);
   Context : Giflib.Internal.LZW.Workspace_Handle;
   Budget : aliased Giflib.Internal.Ownership.Byte_Budget;
   Fault : Giflib.Internal.Ownership.Fault_State;
   Output : Giflib.Streams.Byte_Array (1 .. 1);
   Pixels : Giflib.Pixel_Count := 0;
   Decode_Compressed : Giflib.Byte_Count := 0;
   Skip_Compressed : Giflib.Byte_Count := 0;
   Decode_Outcome : Giflib.Results.Result;
   Skip_Outcome : Giflib.Results.Result;
begin
   Prepare (Context, Budget, Fault);
   Giflib.Streams.Open (Decode_Source);
   Giflib.Streams.Open (Skip_Source);
   Decode_Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Decode_Source, 1, 1, False, Two_Color_Palette,
      Giflib.Limits.Default_Limits, Pixels, Decode_Compressed, Output,
      Frame => 9);
   Skip_Outcome := Giflib.Internal.Image_Data.Skip
     (Skip_Source, Giflib.Limits.Default_Limits, Skip_Compressed,
      Frame => 9);
   Assert
     (Decode_Outcome.First_Error = Skip_Outcome.First_Error,
      "decode and skip disagree on an invalid minimum code size");

   Pixels := 0;
   Decode_Compressed := 0;
   Skip_Compressed := 0;
   Giflib.Streams.Open (Truncated_Decode_Source);
   Giflib.Streams.Open (Truncated_Skip_Source);
   Decode_Outcome := Giflib.Internal.Image_Data.Decode_Indices
     (Context, Truncated_Decode_Source, 1, 1, False, Two_Color_Palette,
      Giflib.Limits.Default_Limits, Pixels, Decode_Compressed, Output,
      Frame => 9);
   Skip_Outcome := Giflib.Internal.Image_Data.Skip
     (Truncated_Skip_Source, Giflib.Limits.Default_Limits, Skip_Compressed,
      Frame => 9);
   Assert
     (Decode_Outcome.First_Error = Skip_Outcome.First_Error,
      "decode and skip disagree on truncated image-data framing");
   Assert
     (Giflib.Internal.Cleanup.Succeeded
        (Giflib.Internal.LZW.Release (Context, Budget)),
      "shared-prefix test leaked its LZW workspace");
end Decode_And_Skip_Share_Prefix_Diagnostics;
