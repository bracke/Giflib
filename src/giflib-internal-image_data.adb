with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Internal.Image_Data is
   use type Errors.Error_Code;

   function Decode_Indices
     (Context : in out LZW.Workspace_Handle;
      Object : in out Streams.Source'Class;
      Descriptor : Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Constraints : Limits.Limit_Set;
      Total_Decoded_Pixels : in out Pixel_Count;
      Total_Compressed_Bytes : in out Byte_Count;
      Output : out Streams.Byte_Array;
      Frame : Frame_Ordinal := 0) return Results.Result
   is
      Expected_Pixels : constant Byte_Count :=
        Geometry_Arithmetic.Area (Descriptor.Width, Descriptor.Height);
      Minimum_Code_Size : Byte;
      Reader : Blocks.Sub_Block_Reader;
      Decoded : Byte_Count;
      Outcome : Results.Result;
   begin
      if Palette.Length = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Missing_Color_Table,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Image_Data_Block,
                Has_Frame => True,
                Frame => Frame,
                others => <>)));
      elsif Byte_Count (Total_Decoded_Pixels) > Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
        or else Total_Compressed_Bytes > Constraints.Max_Compressed_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Image_Data_Block,
                Has_Frame => True,
                Frame => Frame,
                others => <>)));
      elsif Byte_Count (Output'Length) /= Expected_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Output_Size_Mismatch,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Image_Data_Block,
                Has_Frame => True, Frame => Frame,
                Expected => Expected_Pixels,
                Actual => Byte_Count (Output'Length),
                others => <>)));
      elsif Expected_Pixels > Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
        - Byte_Count (Total_Decoded_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Source => Streams.Position (Object).Available,
                Source => Streams.Position (Object).Value,
                Block => Image_Data_Block,
                Has_Frame => True, Frame => Frame,
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
                  (Has_Source => Streams.Position (Object).Available,
                   Source => Streams.Position (Object).Value,
                   Block => Image_Data_Block,
                   Has_Frame => True,
                   Frame => Frame,
                   others => <>)));
         end if;
         return Outcome;
      end if;

      Blocks.Initialize
        (Reader,
         Constraints.Max_Compressed_Bytes - Total_Compressed_Bytes,
         Compressed_Byte_Limit,
         Image_Data_Block);
      Outcome := LZW.Decode
        (Context,
         Object,
         Reader,
         Minimum_Code_Size,
         Output,
         Decoded,
         Constraints.Max_LZW_Work,
         Frame,
         Maximum_Index => Byte (Palette.Length - 1),
         Interlace_Width => (if Descriptor.Interlaced then Natural (Descriptor.Width) else 0),
         Interlace_Height => (if Descriptor.Interlaced then Natural (Descriptor.Height) else 0));
      Total_Compressed_Bytes := Total_Compressed_Bytes + Blocks.Total_Bytes (Reader);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Total_Decoded_Pixels := Total_Decoded_Pixels + Pixel_Count (Decoded);
      return Results.Success;
   end Decode_Indices;
end Giflib.Internal.Image_Data;
