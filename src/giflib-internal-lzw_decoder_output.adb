with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Decoder_Output is
   procedure Emit_Validated
     (Output : in out Streams.Byte_Array;
      Output_Position : in out Natural;
      Value : Byte;
      Layout : Interlacing.Traversal_Layout)
   is
      Target_Position : Natural := Output_Position;
   begin
      if Layout.Is_Interlaced then
         declare
            Stream_Row : constant Natural := Output_Position / Layout.Width;
            Column : constant Natural := Output_Position mod Layout.Width;
            Image_Row : constant Natural :=
              Interlacing.Row_For_Ordinal (Layout.Height, Stream_Row);
         begin
            Target_Position := Image_Row * Layout.Width + Column;
         end;
      end if;
      Output (Output'First + Target_Position) := Value;
      Output_Position := Output_Position + 1;
   end Emit_Validated;

   function Emit
     (Source : Streams.Source'Class;
      Output : in out Streams.Byte_Array;
      Output_Position : in out Natural;
      Value : Byte;
      Work : in out Work_Budgets.Meter;
      Parameters : Emit_Parameters) return Results.Result
   is
   begin
      if Value > Parameters.Maximum_Index then
         return Results.Failure
           (Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               Diagnostics.At_Source
                 (Source,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Parameters.Frame),
                   Expected => Byte_Count (Parameters.Maximum_Index),
                   Actual => Byte_Count (Value), others => <>))));
      elsif Output_Position = Output'Length then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Output_Size_Mismatch,
               Diagnostics.At_Source
                 (Source,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Parameters.Frame),
                   LZW => Errors.LZW_At
                     (0, LZW_Code_Width (Parameters.Code_Width),
                      Parameters.Code_Ordinal),
                   Expected => Byte_Count (Output'Length),
                   Actual => Byte_Count (Output_Position), others => <>))));
      end if;
      if not LZW_Work.Try_Charge (Work, 1) then
         return LZW_Work.Failure (Source, Work, Parameters.Frame);
      end if;
      Emit_Validated (Output, Output_Position, Value, Parameters.Layout);
      return Results.Success;
   end Emit;
end Giflib.Internal.LZW_Decoder_Output;
