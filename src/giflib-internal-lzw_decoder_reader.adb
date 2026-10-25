with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Bit_Arithmetic;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Decoder_Reader is
   function Ordinal (Object : Code_Reader) return Byte_Count is
     (Object.Code_Ordinal);

   function Next_Code
     (Reader : in out Code_Reader;
      Source : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Work : in out Work_Budgets.Meter;
      Parameters : Read_Parameters;
      Value : out LZW_Arithmetic.Code_Value) return Results.Result
   is
      Count : Byte_Count;
      At_End : Boolean;
      Outcome : Results.Result;
      State : LZW_Bit_Arithmetic.Bit_State;
      Extracted : LZW_Bit_Arithmetic.Extracted_Code;
   begin
      Value := 0;
      while Reader.Bit_Count < Parameters.Code_Width loop
         if Reader.Position = Reader.Count then
            Outcome := Blocks.Read_Data
              (Blocks_Reader, Source, Reader.Buffer, Count, At_End);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            elsif Count = 0 and then At_End then
               return Results.Failure
                 (Errors.Make
                    (Errors.LZW_Missing_End_Code,
                     Diagnostics.At_Source
                       (Source,
                        (Block => Image_Data_Block,
                         Frame => Errors.Frame_At (Parameters.Frame),
                         LZW => Errors.LZW_At
                           (0, LZW_Code_Width (Parameters.Code_Width),
                            Reader.Code_Ordinal),
                         Expected => Byte_Count (Parameters.Output_Length),
                         Actual => Byte_Count (Parameters.Output_Position),
                         others => <>))));
            end if;
            Reader.Count := Natural (Count);
            Reader.Position := 0;
         end if;
         Outcome := LZW_Work.Charge (Source, Work, Parameters.Frame, 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         State := LZW_Bit_Arithmetic.Append_Byte
           (Reader.Bit_Buffer,
            LZW_Bit_Arithmetic.Decoder_Append_Count (Reader.Bit_Count),
            Reader.Buffer (Reader.Buffer'First + Reader.Position));
         Reader.Position := Reader.Position + 1;
         Reader.Bit_Buffer := State.Bits;
         Reader.Bit_Count := State.Count;
      end loop;
      Extracted := LZW_Bit_Arithmetic.Extract
        (Reader.Bit_Buffer,
         LZW_Bit_Arithmetic.Bit_Count (Reader.Bit_Count),
         LZW_Bit_Arithmetic.Code_Width (Parameters.Code_Width));
      Value := LZW_Arithmetic.Code_Value (Extracted.Code);
      Reader.Bit_Buffer := Extracted.State.Bits;
      Reader.Bit_Count := Extracted.State.Count;
      Reader.Code_Ordinal := Reader.Code_Ordinal + 1;
      return LZW_Work.Charge (Source, Work, Parameters.Frame, 1);
   end Next_Code;
end Giflib.Internal.LZW_Decoder_Reader;
