with Interfaces;

package Giflib is
   pragma Pure;

   type Byte is new Interfaces.Unsigned_8;
   type Byte_Count is range 0 .. 2 ** 63 - 1;
   type Source_Offset is range 0 .. 2 ** 63 - 1;
   type Destination_Offset is range 0 .. 2 ** 63 - 1;

   type Image_Width is range 1 .. 65_535;
   type Image_Height is range 1 .. 65_535;
   type Coordinate is range 0 .. 65_535;
   type Pixel_Count is range 0 .. 2 ** 63 - 1;
   type Row_Stride is range 0 .. 2 ** 63 - 1;

   type Palette_Index is new Interfaces.Unsigned_8;
   type Palette_Entry_Count is range 2 .. 256;
   type Delay_Centiseconds is range 0 .. 65_535;
   type Frame_Ordinal is range 0 .. 2 ** 31 - 1;

   type LZW_Code is range 0 .. 4_095;
   type LZW_Code_Width is range 2 .. 12;

   type Strictness_Mode is (Strict, Compatible, Recover_When_Safe);
   type GIF_Version is (GIF87a, GIF89a);
   type Pixel_Format is (Indexed_8, RGB_24, BGR_24, RGBA_32, BGRA_32);

   type Block_Kind is
     (No_Block,
      Header_Block,
      Logical_Screen_Descriptor_Block,
      Global_Color_Table_Block,
      Image_Descriptor_Block,
      Local_Color_Table_Block,
      Image_Data_Block,
      Graphic_Control_Extension_Block,
      Comment_Extension_Block,
      Plain_Text_Extension_Block,
      Application_Extension_Block,
      Unknown_Extension_Block,
      Trailer_Block,
      Trailing_Data_Block);

   type Limit_Kind is
     (No_Limit,
      Logical_Width_Limit,
      Logical_Height_Limit,
      Canvas_Pixel_Limit,
      Canvas_Byte_Limit,
      Frame_Count_Limit,
      Frame_Pixel_Limit,
      Total_Decoded_Pixel_Limit,
      Compressed_Byte_Limit,
      Extension_Count_Limit,
      Retained_Metadata_Byte_Limit,
      Per_Extension_Byte_Limit,
      Allocation_Byte_Limit,
      Output_Byte_Limit,
      LZW_Work_Limit,
      Quantization_Work_Limit,
      Optimization_Work_Limit,
      Warning_Record_Limit,
      Diagnostic_Event_Limit,
      Snapshot_Byte_Limit);
end Giflib;
