separate (Giflib.Testing.Test_Optimization)
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
