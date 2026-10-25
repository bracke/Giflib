package Giflib.Limits is
   pragma Preelaborate;

   Maximum_Warning_Records : constant := 256;
   subtype Warning_Record_Limit is
     Natural range 0 .. Maximum_Warning_Records;

   type Limit_Set is record
      Max_Logical_Width : Image_Width := 16_384;
      Max_Logical_Height : Image_Height := 16_384;
      Max_Canvas_Pixels : Pixel_Count := 268_435_456;
      Max_Canvas_Bytes : Byte_Count := 1_073_741_824;
      Max_Frames : Frame_Ordinal := 1_000_000;
      Max_Frame_Pixels : Pixel_Count := 268_435_456;
      Max_Total_Decoded_Frame_Pixels : Pixel_Count := 1_073_741_824;
      Max_Compressed_Bytes : Byte_Count := 1_073_741_824;
      Max_Extensions : Natural := 65_536;
      Max_Retained_Metadata_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_Per_Extension_Bytes : Byte_Count := 16 * 1024 * 1024;
      Max_Allocation_Bytes : Byte_Count := 1_073_741_824;
      Max_Output_Bytes : Byte_Count := 1_073_741_824;
      Max_LZW_Work : Byte_Count := 2 ** 34;
      Max_Quantization_Work : Byte_Count := 2 ** 36;
      Max_Optimization_Work : Byte_Count := 2 ** 34;
      Max_Warning_Records : Warning_Record_Limit := Maximum_Warning_Records;
      Max_Compositor_Snapshot_Bytes : Byte_Count := 1_073_741_824;
   end record;

   Default_Limits : constant Limit_Set := (others => <>);
end Giflib.Limits;
