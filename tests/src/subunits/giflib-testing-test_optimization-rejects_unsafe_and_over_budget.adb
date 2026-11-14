separate (Giflib.Testing.Test_Optimization)
procedure Rejects_Unsafe_And_Over_Budget (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Previous : constant Giflib.Streams.Byte_Array := [0, 0];
   Current : constant Giflib.Streams.Byte_Array := [0, 1];
   Previous_Control : Giflib.Frames.Graphic_Control := Giflib.Frames.Default_Control;
   Item : Giflib.Optimization.Frame_Analysis;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Outcome : Giflib.Results.Result;
begin
   Previous_Control.Disposal := 2;
   Outcome := Giflib.Optimization.Analyze_Indexed
     (Previous, Current, 2, 1, Previous_Control, Giflib.Frames.Default_Control,
      True, Item);
   Assert (Giflib.Results.Succeeded (Outcome)
           and then Item.Action = Giflib.Optimization.Keep_Full_Frame,
           "unsafe disposal was optimized");
   Constraints.Max_Optimization_Work := 1;
   Outcome := Giflib.Optimization.Analyze_Indexed
     (Previous, Current, 2, 1, Giflib.Frames.Default_Control,
      Giflib.Frames.Default_Control, True, Item, Constraints => Constraints);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
           and then Outcome.First_Error.Context.Limit = Giflib.Optimization_Work_Limit,
           "optimization work budget was not enforced");

   Constraints.Max_Optimization_Work := 2;
   Outcome := Giflib.Optimization.Analyze_Indexed
     (Previous, Current, 2, 1, Giflib.Frames.Default_Control,
      Giflib.Frames.Default_Control, True, Item, Constraints => Constraints);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
           and then Outcome.First_Error.Context.Limit = Giflib.Optimization_Work_Limit,
           "transparent-interior scan escaped the optimization work budget");

   Item :=
     (Action => Giflib.Optimization.Trim_To_Rectangle,
      Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
   Constraints.Max_Optimization_Work := 1;
   declare
      Output : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
        (Previous, Current, 2, 1, Item, Output, Constraints => Constraints);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
              and then Outcome.First_Error.Context.Limit = Giflib.Optimization_Work_Limit,
              "rectangle extraction escaped the optimization work budget");
   end;

   declare
      Constrained : Giflib.Optimization.Frame_Analysis
        (Action => Giflib.Optimization.Keep_Full_Frame);
   begin
      Outcome := Giflib.Optimization.Analyze_Indexed
        (Previous, Current, 2, 1,
         Giflib.Frames.Default_Control, Giflib.Frames.Default_Control,
         True, Constrained);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Output_Variant_Mismatch
         and then Constrained.Full_Width = 1,
         "constrained optimization output raised or changed variant");
   end;

   declare
      Short_Previous : constant Giflib.Streams.Byte_Array := [0];
      Output : Giflib.Streams.Byte_Array (1 .. 2);
   begin
      Outcome := Giflib.Optimization.Analyze_Indexed
        (Short_Previous, Current, 2, 1,
         Giflib.Frames.Default_Control, Giflib.Frames.Default_Control,
         True, Item);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
         and then Outcome.First_Error.Context.Expected = 2
         and then Outcome.First_Error.Context.Actual = 1,
         "optimizer input-buffer diagnostic is misleading");
      Item :=
        (Action => Giflib.Optimization.Trim_To_Rectangle,
         Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
      Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
        (Short_Previous, Current, 2, 1, Item, Output);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Buffer_Size_Mismatch
         and then Outcome.First_Error.Context.Expected = 2
         and then Outcome.First_Error.Context.Actual = 1,
         "optimizer extraction reported the wrong buffer extent");
   end;
end Rejects_Unsafe_And_Over_Budget;
