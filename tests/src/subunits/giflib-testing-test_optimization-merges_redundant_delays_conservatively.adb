separate (Giflib.Testing.Test_Optimization)
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
