with Giflib.Errors;
with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;

package body Giflib.Internal.Image_Data.Transport is
   use type Errors.Error_Code;

   function Read_Minimum_Code_Size
     (Object : in out Streams.Source'Class;
      Frame : Frame_Ordinal;
      Minimum_Code_Size : out Byte) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Bytes.Read_Byte (Object, Minimum_Code_Size, Image_Data_Block);
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
           (Errors.Make (Errors.LZW_Invalid_Minimum_Code_Size,
            Diagnostics.At_Source
              (Object, (Block => Image_Data_Block,
                        Frame => Errors.Frame_At (Frame),
                        Actual => Byte_Count (Minimum_Code_Size), others => <>),
               Rewind => 1)));
      end if;
      return Results.Success;
   end Read_Minimum_Code_Size;

   function Process
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Total_Compressed_Bytes : in out Byte_Count;
      Frame : Frame_Ordinal) return Results.Result
   is
      Minimum_Code_Size : Byte;
      Reader : Blocks.Sub_Block_Reader;
      Start_Outcome : Results.Result;
      Outcome : Results.Result;
   begin
      if Total_Compressed_Bytes > Constraints.Max_Compressed_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Frame),
                   others => <>))));
      end if;
      Start_Outcome := Read_Minimum_Code_Size
        (Object, Frame, Minimum_Code_Size);
      if not Results.Succeeded (Start_Outcome) then
         return Start_Outcome;
      end if;
      Blocks.Initialize
        (Reader, Constraints.Max_Compressed_Bytes - Total_Compressed_Bytes,
         Compressed_Byte_Limit, Image_Data_Block);
      begin
         Outcome := Consume (Object, Reader, Minimum_Code_Size);
      exception
         when others =>
            Outcome := Results.Failure
              (Errors.Make
                 (Errors.Internal_Invariant_Failed,
                  Diagnostics.At_Source
                    (Object,
                     (Block => Image_Data_Block,
                      Frame => Errors.Frame_At (Frame),
                      others => <>))));
      end;
      pragma Assert
        (Total_Compressed_Bytes <=
           Byte_Count'Last - Blocks.Total_Bytes (Reader));
      Total_Compressed_Bytes :=
        Total_Compressed_Bytes + Blocks.Total_Bytes (Reader);
      return Outcome;
   end Process;
end Giflib.Internal.Image_Data.Transport;
