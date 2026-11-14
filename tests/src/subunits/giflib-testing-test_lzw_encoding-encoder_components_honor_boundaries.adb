separate (Giflib.Testing.Test_LZW_Encoding)
procedure Encoder_Components_Honor_Boundaries
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [0, 1, 2, 3, 4, 5, 6, 7];
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Blocks_Writer : Giflib.Internal.Blocks.Sub_Block_Writer;
   Writer : Giflib.Internal.LZW_Encoder_Writer.Code_Writer;
   Work : Giflib.Internal.Work_Budgets.Meter (100);
   Outcome : Giflib.Results.Result;
begin
   Assert
     (Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
        Giflib.Internal.LZW_Encoder_Writer.Open,
      "encoder writer did not start open");
   Assert
     (Giflib.Internal.LZW_Encoder_Input.Element
        (Input, 2, Giflib.Internal.Interlacing.Sequential_Layout) = 2,
      "encoder input changed a sequential element");
   Assert
     (Giflib.Internal.LZW_Encoder_Input.Element
        (Input, 2,
         (Is_Interlaced => True, Width => 2, Height => 4)) = 4,
      "encoder input did not apply GIF interlace order");

   Giflib.Streams.Open (Destination);
   Giflib.Internal.Blocks.Initialize (Blocks_Writer, 2, 4);
   Outcome := Giflib.Internal.LZW_Encoder_Writer.Put
     (Writer, Blocks_Writer, Destination, Work, 4, 3);
   Assert (Giflib.Results.Succeeded (Outcome),
           "encoder writer rejected a valid code");
   Outcome := Giflib.Internal.LZW_Encoder_Writer.Finish
     (Writer, Blocks_Writer, Destination);
   Assert (Giflib.Results.Succeeded (Outcome),
           "encoder writer did not flush its partial byte");
   Assert
     (Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
        Giflib.Internal.LZW_Encoder_Writer.Finished,
      "encoder writer did not expose its finished state");
   Outcome := Giflib.Internal.Blocks.Finish (Blocks_Writer, Destination);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Destination.Offset = 3
      and then Storage (1 .. 3) = [1, 4, 0],
      "encoder writer produced the wrong sub-block framing");
   Outcome := Giflib.Internal.LZW_Encoder_Writer.Put
     (Writer, Blocks_Writer, Destination, Work, 4, 3);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
      and then Giflib.Internal.LZW_Encoder_Writer.State (Writer) =
        Giflib.Internal.LZW_Encoder_Writer.Finished,
      "encoder writer accepted a code after finishing");
end Encoder_Components_Honor_Boundaries;
