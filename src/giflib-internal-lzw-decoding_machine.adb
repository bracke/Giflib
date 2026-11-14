with Giflib.Errors;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW.Decoding_Machine.Code_Processing;

package body Giflib.Internal.LZW.Decoding_Machine is
   package Codes renames
     Giflib.Internal.LZW.Decoding_Machine.Code_Processing;

   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Parameters : Decode_Parameters) return Results.Result
   is
      State : Decoder_State (Parameters.Max_Work);
      Code : LZW_Arithmetic.Code_Value;
      Finished : Boolean;
      Outcome : Results.Result;
   begin
      Decoded_Count := 0;
      if Parameters.Minimum_Code_Size < 2
        or else Parameters.Minimum_Code_Size > 8
      then
         return Codes.Failure
           (Object, Output'Length, Parameters.Frame, State,
            Errors.LZW_Invalid_Minimum_Code_Size,
            LZW_Arithmetic.Code_Value (Parameters.Minimum_Code_Size));
      elsif not Interlacing.Is_Valid (Parameters.Layout, Output'Length) then
         State.Code_Width := Natural (Parameters.Minimum_Code_Size) + 1;
         return Results.Failure
           (Errors.Make
              (Errors.Internal_Invariant_Failed,
               Diagnostics.At_Source
                 (Object,
                  (Block => Image_Data_Block,
                   Frame => Errors.Frame_At (Parameters.Frame),
                   others => <>))));
      end if;

      Codes.Initialize (Context, State, Parameters.Minimum_Code_Size);
      loop
         Outcome := LZW_Decoder_Reader.Next_Code
           (State.Reader, Object, Blocks_Reader, State.Work,
            (Code_Width => State.Code_Width,
             Frame => Parameters.Frame,
             Output_Length => Output'Length,
             Output_Position => State.Output_Position),
            Code);
         if Results.Succeeded (Outcome) then
            Outcome := Codes.Process
              (Context, Object, Blocks_Reader, Output, Parameters, State,
               Code, Finished);
         else
            Finished := False;
         end if;
         Decoded_Count := Byte_Count (State.Output_Position);
         if not Results.Succeeded (Outcome) or else Finished then
            return Outcome;
         end if;
      end loop;
   end Decode;
end Giflib.Internal.LZW.Decoding_Machine;
