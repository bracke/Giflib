with AUnit.Assertions;

with Giflib.Errors;
with Giflib.Frames;
with Giflib.Internal.Optimization_Arithmetic;
with Giflib.Limits;
with Giflib.Optimization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib.Testing.Test_Optimization is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Optimization.Optimization_Action;
   use type Giflib.Streams.Byte_Array;

   procedure Trims_And_Extracts_Rectangles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Merges_Redundant_Delays_Conservatively (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Unsafe_And_Over_Budget (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decision_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("optimization");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Trims_And_Extracts_Rectangles'Access,
                        "optimization.rectangle_and_transparent_interior");
      Register_Routine (T, Merges_Redundant_Delays_Conservatively'Access,
                        "optimization.redundant_delay_merge");
      Register_Routine (T, Rejects_Unsafe_And_Over_Budget'Access,
                        "optimization.disposal_and_budget_guards");
      Register_Routine (T, Decision_Arithmetic_Is_Bounded'Access,
                        "optimization.decision_arithmetic");
   end Register_Tests;

   procedure Decision_Arithmetic_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Arithmetic renames Giflib.Internal.Optimization_Arithmetic;
      Bounds : Arithmetic.Change_Bounds;
      Unsafe : Giflib.Frames.Graphic_Control := Giflib.Frames.Default_Control;
   begin
      Bounds := Arithmetic.Include (Bounds, 5, 7);
      Bounds := Arithmetic.Include (Bounds, 2, 9);
      Assert (not Bounds.Empty
              and then Bounds.Min_X = 2 and then Bounds.Max_X = 5
              and then Bounds.Min_Y = 7 and then Bounds.Max_Y = 9
              and then Natural (Arithmetic.Width (Bounds)) = 4
              and then Natural (Arithmetic.Height (Bounds)) = 3,
              "optimizer change bounds are wrong");
      Assert (Arithmetic.Is_Safe
                (Giflib.Frames.Default_Control, Giflib.Frames.Default_Control, True),
              "safe optimizer controls were rejected");
      Unsafe.Disposal := 2;
      Assert (not Arithmetic.Is_Safe (Unsafe, Giflib.Frames.Default_Control, True),
              "unsafe optimizer controls were accepted");
      Assert (Arithmetic.Can_Merge_Delay (65_530, 5)
              and then Arithmetic.Merge_Delay (65_530, 5) = 65_535
              and then not Arithmetic.Can_Merge_Delay (65_535, 1),
              "optimizer delay bounds are wrong");
   end Decision_Arithmetic_Is_Bounded;

   procedure Trims_And_Extracts_Rectangles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Previous : constant Giflib.Streams.Byte_Array := [for I in 1 .. 12 => 0];
      Current : constant Giflib.Streams.Byte_Array := [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0];
      Item : Giflib.Optimization.Frame_Analysis;
      Options : Giflib.Optimization.Optimization_Options := Giflib.Optimization.Default_Options;
      Output : Giflib.Streams.Byte_Array (1 .. 6);
      Outcome : Giflib.Results.Result;
   begin
      Options.Transparent_Index := 2;
      Outcome := Giflib.Optimization.Analyze_Indexed
        (Previous, Current, 4, 3, Giflib.Frames.Default_Control,
         Giflib.Frames.Default_Control, True, Item, Options);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Item.Action = Giflib.Optimization.Trim_To_Rectangle
              and then Item.Left = 1 and then Item.Top = 0
              and then Item.Width = 2 and then Item.Height = 3
              and then Item.Requires_Transparency,
              "changed rectangle analysis was wrong");
      Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
        (Previous, Current, 4, 3, Item, Output, Options);
      Assert (Giflib.Results.Succeeded (Outcome) and then Output = [1, 2, 2, 2, 2, 1],
              "transparent-interior rectangle extraction was wrong");

      declare
         Conflict_Previous : constant Giflib.Streams.Byte_Array := [1, 1, 1];
         Conflict_Current : constant Giflib.Streams.Byte_Array := [0, 1, 2];
         Conflict_Output : Giflib.Streams.Byte_Array (1 .. 3);
      begin
         Options.Transparent_Index := 0;
         Outcome := Giflib.Optimization.Analyze_Indexed
           (Conflict_Previous, Conflict_Current, 3, 1,
            Giflib.Frames.Default_Control, Giflib.Frames.Default_Control,
            True, Item, Options);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Item.Action = Giflib.Optimization.Trim_To_Rectangle
                 and then not Item.Requires_Transparency,
                 "changed transparent-index pixel was made transparent");
         Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
           (Conflict_Previous, Conflict_Current, 3, 1, Item, Conflict_Output, Options);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Conflict_Output = Conflict_Current,
                 "transparent-index conflict changed optimized pixels");
      end;

      declare
         Mismatch_Previous : constant Giflib.Streams.Byte_Array := [0, 0, 0];
         Mismatch_Current : constant Giflib.Streams.Byte_Array := [1, 0, 2];
         Mismatch_Output : Giflib.Streams.Byte_Array (1 .. 3);
         Extraction_Options : Giflib.Optimization.Optimization_Options := Options;
      begin
         Options.Transparent_Index := 3;
         Outcome := Giflib.Optimization.Analyze_Indexed
           (Mismatch_Previous, Mismatch_Current, 3, 1,
            Giflib.Frames.Default_Control, Giflib.Frames.Default_Control,
            True, Item, Options);
         Assert (Giflib.Results.Succeeded (Outcome) and then Item.Requires_Transparency,
                 "safe analysis did not request transparent interior pixels");
         Extraction_Options.Transparent_Index := 1;
         Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
           (Mismatch_Previous, Mismatch_Current, 3, 1, Item, Mismatch_Output,
            Extraction_Options);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Mismatch_Output = Mismatch_Current,
                 "changed extraction options made a changed pixel transparent");
      end;

      declare
         Maximum_Bound_Previous : constant Giflib.Streams.Byte_Array
           (Positive'Last .. Positive'Last) := [others => 0];
         Maximum_Bound_Current : constant Giflib.Streams.Byte_Array
           (Positive'Last .. Positive'Last) := [others => 1];
         Maximum_Bound_Output : Giflib.Streams.Byte_Array
           (Positive'Last .. Positive'Last);
      begin
         Outcome := Giflib.Optimization.Analyze_Indexed
           (Maximum_Bound_Previous,
            Maximum_Bound_Current,
            1,
            1,
            Giflib.Frames.Default_Control,
            Giflib.Frames.Default_Control,
            True,
            Item);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Item.Action = Giflib.Optimization.Trim_To_Rectangle,
            "optimization rejected valid maximum-bound input arrays");
         Outcome := Giflib.Optimization.Extract_Indexed_Rectangle
           (Maximum_Bound_Previous,
            Maximum_Bound_Current,
            1,
            1,
            Item,
            Maximum_Bound_Output);
         Assert
           (Giflib.Results.Succeeded (Outcome)
            and then Maximum_Bound_Output (Positive'Last) = 1,
            "optimization rejected a valid maximum-bound output array");
      end;
   end Trims_And_Extracts_Rectangles;

   procedure Merges_Redundant_Delays_Conservatively
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Pixels : constant Giflib.Streams.Byte_Array := [1, 2];
      Previous_Control : Giflib.Frames.Graphic_Control := Giflib.Frames.Default_Control;
      Current_Control : Giflib.Frames.Graphic_Control := Giflib.Frames.Default_Control;
      Item : Giflib.Optimization.Frame_Analysis;
      Outcome : Giflib.Results.Result;
   begin
      Previous_Control.Delay_CS := 3;
      Current_Control.Delay_CS := 4;
      Outcome := Giflib.Optimization.Analyze_Indexed
        (Pixels, Pixels, 2, 1, Previous_Control, Current_Control, True, Item);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Item.Action = Giflib.Optimization.Merge_With_Previous
              and then Item.Merged_Delay = 7,
              "redundant frame delays were not merged");
      Previous_Control.Delay_CS := 65_535;
      Outcome := Giflib.Optimization.Analyze_Indexed
        (Pixels, Pixels, 2, 1, Previous_Control, Current_Control, True, Item);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Item.Action = Giflib.Optimization.Keep_Full_Frame,
              "delay overflow incorrectly merged a redundant frame");
   end Merges_Redundant_Delays_Conservatively;

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
   end Rejects_Unsafe_And_Over_Budget;
end Giflib.Testing.Test_Optimization;
