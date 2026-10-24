with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.LZW;

package body Giflib.Internal.Image_Data is
   use type Errors.Error_Code;

   function Decode_Indices
     (Object : in out Streams.Source'Class;
      Descriptor : Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Output : out Streams.Byte_Array;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
      Expected_Pixels : constant Byte_Count :=
        Byte_Count (Descriptor.Width) * Byte_Count (Descriptor.Height);
      Minimum_Code_Size : Byte;
      Reader : Blocks.Sub_Block_Reader;
      Decoded : Byte_Count;
      Outcome : Results.Result;
   begin
      if Palette.Length = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Missing_Color_Table,
               (Source => Object.Offset, Block => Image_Data_Block, Frame => Frame, others => <>)));
      elsif Byte_Count (Total_Decoded_Pixels) > Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
        or else Total_Compressed_Bytes > Constraints.Max_Compressed_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Source => Object.Offset, Block => Image_Data_Block, Frame => Frame, others => <>)));
      elsif Byte_Count (Output'Length) /= Expected_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Output_Size_Mismatch,
               (Source => Object.Offset,
                Block => Image_Data_Block,
                Frame => Frame,
                Expected => Expected_Pixels,
                Actual => Byte_Count (Output'Length),
                others => <>)));
      elsif Expected_Pixels > Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
        - Byte_Count (Total_Decoded_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Offset,
                Block => Image_Data_Block,
                Frame => Frame,
                Expected => Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels),
                Actual => Byte_Count (Total_Decoded_Pixels) + Expected_Pixels,
                Limit => Total_Decoded_Pixel_Limit,
                others => <>)));
      end if;

      Outcome := Bytes.Read_Byte (Object, Minimum_Code_Size, Image_Data_Block);
      if not Results.Succeeded (Outcome) then
         if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
            return Results.Failure
              (Errors.Make
                 (Errors.Truncated_Block,
                  (Source => Object.Offset, Block => Image_Data_Block, Frame => Frame, others => <>)));
         end if;
         return Outcome;
      end if;

      Blocks.Initialize
        (Reader,
         Constraints.Max_Compressed_Bytes - Total_Compressed_Bytes,
         Compressed_Byte_Limit,
         Image_Data_Block);
      Outcome := LZW.Decode
        (Object,
         Reader,
         Minimum_Code_Size,
         Output,
         Decoded,
         Constraints.Max_LZW_Work,
         Frame,
         Interlace_Width => (if Descriptor.Interlaced then Natural (Descriptor.Width) else 0),
         Interlace_Height => (if Descriptor.Interlaced then Natural (Descriptor.Height) else 0));
      Total_Compressed_Bytes := Total_Compressed_Bytes + Blocks.Total_Bytes (Reader);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      for I in Output'Range loop
         if not Palettes.Contains (Palette, Palette_Index (Output (I))) then
            return Results.Failure
              (Errors.Make
                 (Errors.Palette_Index_Out_Of_Range,
                  (Source => Object.Offset,
                   Block => Image_Data_Block,
                   Frame => Frame,
                   Expected => Byte_Count (Palette.Length - 1),
                   Actual => Byte_Count (Output (I)),
                   others => <>)));
         end if;
      end loop;

      Total_Decoded_Pixels := Total_Decoded_Pixels + Pixel_Count (Decoded);
      return Results.Success;
   end Decode_Indices;
end Giflib.Internal.Image_Data;
