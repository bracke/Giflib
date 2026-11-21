with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Bit_Arithmetic;
with Giflib.Internal.LZW_Work;
with Giflib.Results;

package body Giflib.Internal.LZW_Decoder_Reader is
   function Ordinal (Object : Code_Reader) return Byte_Count is
     (Object.Code_Ordinal);

   function Failure_Error (Object : Code_Reader) return Errors.Error is
     (Object.Last_Error);

   function Refill
     (Reader : in out Code_Reader;
      Source : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Parameters : Read_Parameters) return Read_Status
   is
      Count : Byte_Count;
      At_End : Boolean;
      Outcome : Results.Result;
   begin
      Outcome := Blocks.Read_Data
        (Blocks_Reader, Source, Reader.Buffer, Count, At_End);
      if not Results.Succeeded (Outcome) then
         Reader.Last_Error := Outcome.First_Error;
         return Read_Failed;
      elsif Count = 0 and then At_End then
         Reader.Last_Error := Errors.Make
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
                others => <>)));
         return Read_Failed;
      end if;
      Reader.Count := Natural (Count);
      Reader.Position := 0;
      return Read_Ready;
   end Refill;
   pragma No_Inline (Refill);

   function Next_Code
     (Reader : in out Code_Reader;
      Source : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Work : in out Work_Budgets.Meter;
      Pending_Work : in out Byte_Count;
      Parameters : Read_Parameters;
      Value : out LZW_Arithmetic.Code_Value) return Read_Status
   is
      State : LZW_Bit_Arithmetic.Bit_State;
      Extracted : LZW_Bit_Arithmetic.Extracted_Code;
      Bytes_Consumed : Byte_Count := 0;
   begin
      Value := 0;
      while Reader.Bit_Count < Parameters.Code_Width loop
         if Reader.Position = Reader.Count then
            if Refill (Reader, Source, Blocks_Reader, Parameters) /= Read_Ready
            then
               return Read_Failed;
            end if;
         end if;
         State := LZW_Bit_Arithmetic.Append_Byte
           (Reader.Bit_Buffer,
            LZW_Bit_Arithmetic.Decoder_Append_Count (Reader.Bit_Count),
            Reader.Buffer (Reader.Buffer'First + Reader.Position));
         Reader.Position := Reader.Position + 1;
         Reader.Bit_Buffer := State.Bits;
         Reader.Bit_Count := State.Count;
         Bytes_Consumed := Bytes_Consumed + 1;
      end loop;
      Extracted := LZW_Bit_Arithmetic.Extract
        (Reader.Bit_Buffer,
         LZW_Bit_Arithmetic.Bit_Count (Reader.Bit_Count),
         LZW_Bit_Arithmetic.Code_Width (Parameters.Code_Width));
      Value := LZW_Arithmetic.Code_Value (Extracted.Code);
      Reader.Bit_Buffer := Extracted.State.Bits;
      Reader.Bit_Count := Extracted.State.Count;
      if not LZW_Work.Accumulate
        (Work, Pending_Work, Bytes_Consumed + 1, 4_096)
      then
         Reader.Last_Error :=
           LZW_Work.Failure (Source, Work, Parameters.Frame).First_Error;
         return Read_Failed;
      end if;
      Reader.Code_Ordinal := Reader.Code_Ordinal + 1;
      return Read_Ready;
   end Next_Code;
end Giflib.Internal.LZW_Decoder_Reader;
