with Giflib.Errors;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Interlacing;

package body Giflib.Internal.Image_Data is
   use type Errors.Error_Code;

   function Read_Minimum_Code_Size
     (Object : in out Streams.Source'Class;
      Frame : Frame_Ordinal;
      Minimum_Code_Size : out Byte) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Bytes.Read_Byte
        (Object, Minimum_Code_Size, Image_Data_Block);
      if not Results.Succeeded (Outcome) then
         if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
            declare
               Item : Errors.Error := Outcome.First_Error;
            begin
               Item.Code := Errors.Truncated_Block;
               Item.Context.Block := Image_Data_Block;
               Item.Context.Frame := Errors.Frame_At (Frame);
               Item.Context := Diagnostics.At_Source (Object, Item.Context);
               return Results.Failure (Item);
            end;
         end if;
         return Outcome;
      elsif Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Invalid_Minimum_Code_Size,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   Actual => Byte_Count (Minimum_Code_Size),
                   others => <>),
                  Rewind => 1)));
      end if;
      return Results.Success;
   end Read_Minimum_Code_Size;

   function Validate_Compressed_State
     (Object : Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Total_Compressed_Bytes : Byte_Count;
      Frame : Frame_Ordinal) return Results.Result
     with Post =>
       (if Results.Succeeded (Validate_Compressed_State'Result)
        then Total_Compressed_Bytes <= Constraints.Max_Compressed_Bytes)
   is
   begin
      if Total_Compressed_Bytes > Constraints.Max_Compressed_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame), others => <>))));
      end if;
      return Results.Success;
   end Validate_Compressed_State;

   function Begin_Image_Data
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Total_Compressed_Bytes : Byte_Count;
      Frame : Frame_Ordinal;
      Minimum_Code_Size : out Byte;
      Reader : in out Blocks.Sub_Block_Reader) return Results.Result
     with Pre =>
       Total_Compressed_Bytes <= Constraints.Max_Compressed_Bytes,
          Post =>
            (if Results.Succeeded (Begin_Image_Data'Result)
             then Blocks.Total_Bytes (Reader) = 0
               and then not Blocks.Finished (Reader))
   is
      Outcome : Results.Result;
   begin
      Outcome := Read_Minimum_Code_Size
        (Object, Frame, Minimum_Code_Size);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Blocks.Initialize
        (Reader,
         Constraints.Max_Compressed_Bytes - Total_Compressed_Bytes,
         Compressed_Byte_Limit,
         Image_Data_Block);
      return Results.Success;
   end Begin_Image_Data;

   procedure Account_Compressed_Bytes
     (Reader : Blocks.Sub_Block_Reader;
      Total_Compressed_Bytes : in out Byte_Count)
     with Pre =>
       Total_Compressed_Bytes <= Byte_Count'Last - Blocks.Total_Bytes (Reader),
          Post => Total_Compressed_Bytes =
            Total_Compressed_Bytes'Old + Blocks.Total_Bytes (Reader)
   is
   begin
      Total_Compressed_Bytes :=
        Total_Compressed_Bytes + Blocks.Total_Bytes (Reader);
   end Account_Compressed_Bytes;

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
      Minimum_Code_Size : Byte;
      Reader : Blocks.Sub_Block_Reader;
      Decoded : Byte_Count;
      Outcome : Results.Result;
   begin
      if Palette.Length = 0 then
         return Results.Failure
           (Errors.Make
              (Errors.Missing_Color_Table,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   others => <>))));
      elsif Byte_Count (Total_Decoded_Pixels) >
        Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   others => <>))));
      end if;
      Outcome := Validate_Compressed_State
        (Object, Constraints, Total_Compressed_Bytes, Frame);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Byte_Count (Output'Length) /= Expected_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   Expected => Expected_Pixels,
                   Actual => Byte_Count (Output'Length),
                   others => <>))));
      elsif Expected_Pixels > Byte_Count (Constraints.Max_Total_Decoded_Frame_Pixels)
        - Byte_Count (Total_Decoded_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   Expected => Byte_Count
                     (Constraints.Max_Total_Decoded_Frame_Pixels),
                   Actual => Byte_Count (Total_Decoded_Pixels) + Expected_Pixels,
                   Limit => Total_Decoded_Pixel_Limit,
                   others => <>))));
      end if;

      Outcome := Begin_Image_Data
        (Object, Constraints, Total_Compressed_Bytes, Frame,
         Minimum_Code_Size, Reader);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := LZW.Decode
        (Context,
         Object,
         Reader,
         Output,
         Decoded,
         (Minimum_Code_Size => Minimum_Code_Size,
          Max_Work => Constraints.Max_LZW_Work,
          Frame => Frame,
          Maximum_Index => Byte (Palette.Length - 1),
          Layout =>
            (if Interlaced
             then (Is_Interlaced => True,
                   Width => Natural (Width),
                   Height => Natural (Height))
             else Interlacing.Sequential_Layout)));
      Account_Compressed_Bytes (Reader, Total_Compressed_Bytes);
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
      Minimum_Code_Size : Byte;
      Reader : Blocks.Sub_Block_Reader;
      Outcome : Results.Result;
   begin
      Outcome := Validate_Compressed_State
        (Object, Constraints, Total_Compressed_Bytes, Frame);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Begin_Image_Data
        (Object, Constraints, Total_Compressed_Bytes, Frame,
         Minimum_Code_Size, Reader);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Blocks.Drain (Reader, Object);
      Account_Compressed_Bytes (Reader, Total_Compressed_Bytes);
      return Outcome;
   end Skip;
end Giflib.Internal.Image_Data;
