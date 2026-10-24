with AUnit.Assertions;

with Giflib;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Optimization;
with Giflib.Results;
with Giflib.Streams;

package body Giflib_Testing.Test_Optimization is
   use AUnit.Assertions;
   use type Giflib.Coordinate;
   use type Giflib.Delay_Centiseconds;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Limit_Kind;
   use type Giflib.Optimization.Optimization_Action;
   use type Giflib.Streams.Byte_Array;

   procedure Trims_And_Extracts_Rectangles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Merges_Redundant_Delays_Conservatively (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Rejects_Unsafe_And_Over_Budget (T : in out AUnit.Test_Cases.Test_Case'Class);

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
   end Register_Tests;

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
      Assert (Item.Action = Giflib.Optimization.Keep_Full_Frame,
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
   end Rejects_Unsafe_And_Over_Budget;
end Giflib_Testing.Test_Optimization;
