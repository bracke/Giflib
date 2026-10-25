with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Decoder_Output is
   function Emit
     (Source : Streams.Source'Class;
      Output : in out Streams.Byte_Array;
      Output_Position : in out Natural;
      Value : Byte;
      Work : in out Work_Budgets.Meter;
      Parameters : Emit_Parameters) return Results.Result
   is
      Outcome : Results.Result;
      Target_Position : Natural := Output_Position;
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
      if Parameters.Layout.Is_Interlaced then
         declare
            Stream_Row : constant Natural :=
              Output_Position / Parameters.Layout.Width;
            Column : constant Natural :=
              Output_Position mod Parameters.Layout.Width;
            Image_Row : constant Natural :=
              Interlacing.Row_For_Ordinal
                (Parameters.Layout.Height, Stream_Row);
         begin
            if Image_Row >= Parameters.Layout.Height then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     Diagnostics.At_Source
                       (Source,
                        (Block => Image_Data_Block,
                         Frame => Errors.Frame_At (Parameters.Frame),
                         others => <>))));
            end if;
            Target_Position :=
              Image_Row * Parameters.Layout.Width + Column;
         end;
      end if;
      Outcome := LZW_Work.Charge
        (Source, Work, Parameters.Frame, 1);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Output (Output'First + Target_Position) := Value;
      Output_Position := Output_Position + 1;
      return Results.Success;
   end Emit;
end Giflib.Internal.LZW_Decoder_Output;
