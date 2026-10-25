with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.Interlacing;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Decoder_Output
  with Preelaborate
is
   type Emit_Parameters is record
      Code_Ordinal : Byte_Count;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout;
      Code_Width : LZW_Arithmetic.Active_Code_Width;
      Frame : Frame_Ordinal := 0;
   end record;

   function Emit
     (Source : Streams.Source'Class;
      Output : in out Streams.Byte_Array;
      Output_Position : in out Natural;
      Value : Byte;
      Work : in out Work_Budgets.Meter;
      Parameters : Emit_Parameters) return Results.Result
     with Pre => Output_Position <= Output'Length
                 and then Interlacing.Is_Valid
                   (Parameters.Layout, Output'Length),
          Post =>
            (if Results.Succeeded (Emit'Result)
             then Output_Position = Output_Position'Old + 1);
end Giflib.Internal.LZW_Decoder_Output;
