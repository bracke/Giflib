separate (Giflib.Testing.Test_Compositing)
procedure Transparent_Initial_Canvas_And_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   No_Global : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 2, 0, 1, 0, 0, 0, 0,
      16#2C#, 1, 0, 0, 0, 1, 0, 1, 0, 16#80#,
      0, 0, 0, 255, 255, 255,
      2, 2, 16#4C#, 1, 0, 16#3B#];
   Snapshot_Limited : aliased constant Giflib.Streams.Byte_Array :=
     Header & GCE (3) & Two_Red_Pixels & [16#3B#];
   Source : aliased Giflib.Streams.Memory_Source (No_Global'Access);
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Snapshot_Source : aliased Giflib.Streams.Memory_Source
     (Snapshot_Limited'Access);
   Snapshot_Decoder : Giflib.Decoding.Decoder (Snapshot_Source'Access);
   Canvas : Giflib.Streams.Byte_Array (1 .. 8);
   Info : Giflib.Decoding.Frame_Info;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Outcome : Giflib.Results.Result;
begin
   Begin_Decoder (Source, Decoder, Outcome => Outcome);
   Next_Canvas (Decoder, Canvas, Info, Outcome);
   Assert (Giflib.Results.Succeeded (Outcome), "transparent initial canvas decode failed");
   Assert (Canvas = [0, 0, 0, 0, 255, 255, 255, 255],
           "missing background did not initialize transparent");

   Giflib.Decoding.Finalize (Decoder);
   Constraints.Max_Compositor_Snapshot_Bytes := 7;
   Begin_Decoder
     (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
   Next_Canvas (Snapshot_Decoder, Canvas, Info, Outcome);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded,
           "snapshot budget was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Snapshot_Byte_Limit,
           "snapshot budget lost context");

   Giflib.Decoding.Finalize (Snapshot_Decoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Canvas_Pixels := 1;
   Begin_Decoder
     (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Canvas_Pixel_Limit,
           "canvas pixel budget was ignored");

   Giflib.Decoding.Finalize (Snapshot_Decoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Canvas_Bytes := 7;
   Begin_Decoder
     (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Canvas_Byte_Limit,
           "canvas byte budget was ignored");

   Giflib.Decoding.Finalize (Snapshot_Decoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Allocation_Bytes := 7;
   Begin_Decoder
     (Snapshot_Source, Snapshot_Decoder, Constraints, Outcome);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Allocation_Byte_Limit,
           "decoder allocation budget was ignored");
end Transparent_Initial_Canvas_And_Budgets;
