with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Image_Data.Transport;
with Giflib.Internal.Interlacing;

package body Giflib.Internal.Image_Data is
   function Decode_Indices
     (Context : in out LZW.Workspace_Handle;
      Object : in out Streams.Source'Class;
      Width : Image_Width;
      Height : Image_Height;
      Interlaced : Boolean;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Output : out Streams.Byte_Array;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
      Expected_Pixels : constant Byte_Count :=
        Geometry_Arithmetic.Area (Width, Height);
      Decoded : Byte_Count;
      Outcome : Results.Result;

      function Consume
        (Source : in out Streams.Source'Class;
         Reader : in out Blocks.Sub_Block_Reader;
         Minimum_Code_Size : Byte) return Results.Result is
        (LZW.Decode
           (Context, Source, Reader, Output, Decoded,
            (Minimum_Code_Size => Minimum_Code_Size,
             Max_Work => Constraints.Max_LZW_Work,
             Frame => Frame,
             Maximum_Index => Byte (Palette.Length - 1),
             Layout =>
               (if Interlaced
                then (Is_Interlaced => True, Width => Natural (Width),
                      Height => Natural (Height))
                else Interlacing.Sequential_Layout))));

      function Process is new Transport.Process (Consume);
   begin
      if Palette.Length = 0 then
         return Results.Failure
           (Errors.Make (Errors.Missing_Color_Table,
            Diagnostics.At_Source
              (Object, (Block => Image_Data_Block,
                        Frame => Errors.Frame_At (Frame), others => <>))));
      elsif Byte_Count (Total_Decoded_Pixels) >
        Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed,
            Diagnostics.At_Source
              (Object, (Block => Image_Data_Block,
                        Frame => Errors.Frame_At (Frame), others => <>))));
      end if;
      if Byte_Count (Output'Length) /= Expected_Pixels then
         return Results.Failure
           (Errors.Make (Errors.Buffer_Size_Mismatch,
            Diagnostics.At_Source
              (Object, (Block => Image_Data_Block,
                        Frame => Errors.Frame_At (Frame),
                        Expected => Expected_Pixels,
                        Actual => Byte_Count (Output'Length), others => <>))));
      elsif Expected_Pixels > Byte_Count
        (Constraints.Max_Total_Decoded_Frame_Pixels)
          - Byte_Count (Total_Decoded_Pixels)
      then
         return Results.Failure
           (Errors.Make (Errors.Limit_Exceeded,
            Diagnostics.At_Source
              (Object, (Block => Image_Data_Block,
                        Frame => Errors.Frame_At (Frame),
                        Expected => Byte_Count
                          (Constraints.Max_Total_Decoded_Frame_Pixels),
                        Actual => Byte_Count (Total_Decoded_Pixels)
                          + Expected_Pixels,
                        Limit => Total_Decoded_Pixel_Limit, others => <>))));
      end if;
      Outcome := Process
        (Object, Constraints, Total_Compressed_Bytes, Frame);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Total_Decoded_Pixels := Total_Decoded_Pixels + Pixel_Count (Decoded);
      return Results.Success;
   end Decode_Indices;

   function Skip
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Total_Compressed_Bytes : in out Byte_Count;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
      Outcome : Results.Result;

      function Consume
        (Source : in out Streams.Source'Class;
         Reader : in out Blocks.Sub_Block_Reader;
         Minimum_Code_Size : Byte) return Results.Result
      is
         pragma Unreferenced (Minimum_Code_Size);
      begin
         return Blocks.Drain (Reader, Source);
      end Consume;

      function Process is new Transport.Process (Consume);
   begin
      Outcome := Process
        (Object, Constraints, Total_Compressed_Bytes, Frame);
      return Outcome;
   end Skip;
end Giflib.Internal.Image_Data;
