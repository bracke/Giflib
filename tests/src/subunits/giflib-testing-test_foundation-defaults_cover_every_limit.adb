separate (Giflib.Testing.Test_Foundation)
procedure Defaults_Cover_Every_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   L : constant Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
begin
   Assert (L.Max_Logical_Width = 4_096, "unexpected default width limit");
   Assert (L.Max_Logical_Height = 4_096, "unexpected default height limit");
   Assert (L.Max_Canvas_Pixels > 0, "canvas pixel limit disabled");
   Assert (L.Max_Canvas_Bytes > 0, "canvas byte limit disabled");
   Assert (L.Max_Frames > 0, "frame limit disabled");
   Assert (L.Max_Frame_Pixels > 0, "frame pixel limit disabled");
   Assert (L.Max_Total_Decoded_Frame_Pixels > 0, "total decoded pixel limit disabled");
   Assert (L.Max_Compressed_Bytes > 0, "compressed byte limit disabled");
   Assert (L.Max_Extensions > 0, "extension count limit disabled");
   Assert (L.Max_Retained_Metadata_Bytes > 0, "metadata limit disabled");
   Assert (L.Max_Per_Extension_Bytes > 0, "per-extension limit disabled");
   Assert (L.Max_Allocation_Bytes > 0, "allocation limit disabled");
   Assert (L.Max_Output_Bytes > 0, "output limit disabled");
   Assert (L.Max_LZW_Work = 2 ** 26, "unexpected LZW work limit");
   Assert
     (L.Max_Quantization_Work = 2 ** 28,
      "unexpected quantization work limit");
   Assert
     (L.Max_Optimization_Work = 2 ** 26,
      "unexpected optimization work limit");
   Assert (L.Max_Warning_Records > 0, "warning limit disabled");
   Assert (L.Max_Compositor_Snapshot_Bytes > 0, "snapshot limit disabled");
   Assert
     (L.Max_Allocation_Bytes = 64 * 1024 * 1024
      and then L.Max_Canvas_Bytes = 16 * 1024 * 1024
      and then L.Max_Compositor_Snapshot_Bytes = 16 * 1024 * 1024,
      "default memory limits are not conservative");
   Assert
     (Giflib.Limits.High_Capacity_Limits.Max_Allocation_Bytes >
        L.Max_Allocation_Bytes
      and then Giflib.Limits.High_Capacity_Limits.Max_LZW_Work >
        L.Max_LZW_Work
      and then Giflib.Limits.High_Capacity_Limits.Max_Quantization_Work >
        L.Max_Quantization_Work
      and then Giflib.Limits.High_Capacity_Limits.Max_Optimization_Work >
        L.Max_Optimization_Work,
      "high-capacity limits are not an explicit larger profile");
end Defaults_Cover_Every_Limit;

