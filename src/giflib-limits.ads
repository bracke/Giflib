package Giflib.Limits is
   pragma Preelaborate;

   Maximum_Warning_Records : constant := 256;
   subtype Warning_Record_Limit is
     Natural range 0 .. Maximum_Warning_Records;

   type Limit_Set is record
      Max_Logical_Width : Image_Width := 4_096;
      Max_Logical_Height : Image_Height := 4_096;
      Max_Canvas_Pixels : Pixel_Count := 4_194_304;
      Max_Canvas_Bytes : Byte_Count := 16 * 1024 * 1024;
      Max_Frames : Frame_Ordinal := 10_000;
      Max_Frame_Pixels : Pixel_Count := 4_194_304;
      Max_Total_Decoded_Frame_Pixels : Pixel_Count := 64 * 1024 * 1024;
      Max_Compressed_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_Extensions : Natural := 4_096;
      Max_Retained_Metadata_Bytes : Byte_Count := 8 * 1024 * 1024;
      Max_Per_Extension_Bytes : Byte_Count := 2 * 1024 * 1024;
      Max_Allocation_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_Output_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_LZW_Work : Byte_Count := 2 ** 26;
      Max_Quantization_Work : Byte_Count := 2 ** 28;
      Max_Optimization_Work : Byte_Count := 2 ** 26;
      Max_Warning_Records : Warning_Record_Limit := Maximum_Warning_Records;
      Max_Compositor_Snapshot_Bytes : Byte_Count := 16 * 1024 * 1024;
   end record;

   --  Conservative defaults for untrusted inputs.
   Default_Limits : constant Limit_Set := (others => <>);

   --  Explicit opt-in ceilings for trusted, high-capacity batch workloads.
   High_Capacity_Limits : constant Limit_Set :=
     (Max_Logical_Width => 16_384,
      Max_Logical_Height => 16_384,
      Max_Canvas_Pixels => 268_435_456,
      Max_Canvas_Bytes => 1_073_741_824,
      Max_Frames => 1_000_000,
      Max_Frame_Pixels => 268_435_456,
      Max_Total_Decoded_Frame_Pixels => 1_073_741_824,
      Max_Compressed_Bytes => 1_073_741_824,
      Max_Extensions => 65_536,
      Max_Retained_Metadata_Bytes => 64 * 1024 * 1024,
      Max_Per_Extension_Bytes => 16 * 1024 * 1024,
      Max_Allocation_Bytes => 1_073_741_824,
      Max_Output_Bytes => 1_073_741_824,
      Max_LZW_Work => 2 ** 34,
      Max_Quantization_Work => 2 ** 36,
      Max_Optimization_Work => 2 ** 34,
      Max_Warning_Records => Maximum_Warning_Records,
      Max_Compositor_Snapshot_Bytes => 1_073_741_824);
end Giflib.Limits;
