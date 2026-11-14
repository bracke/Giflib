separate (Giflib.Testing.Test_Blocks)
procedure Writer_Enforces_Wire_Limit
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Short_Storage : aliased Giflib.Streams.Byte_Array := [0];
   Short_Destination :
     Giflib.Streams.Fixed_Buffer_Destination (Short_Storage'Access);
   Writer : Giflib.Internal.Blocks.Sub_Block_Writer;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination);
   Giflib.Internal.Blocks.Initialize
     (Writer, Max_Payload_Bytes => 1, Max_Wire_Bytes => 2);
   Outcome := Giflib.Internal.Blocks.Write_Data (Writer, Destination, [1 => 42]);
   Assert (Giflib.Results.Succeeded (Outcome), "writer rejected bounded payload");
   Outcome := Giflib.Internal.Blocks.Finish (Writer, Destination);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
      and then Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit,
      "writer accepted a terminator beyond the wire limit");
   Assert
     (Destination.Offset = 2
      and then Giflib.Internal.Blocks.Total_Wire_Bytes (Writer) = 2,
      "writer wire accounting changed after a rejected terminator");
   Outcome := Giflib.Internal.Blocks.Finish (Writer, Destination);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
      and then Destination.Offset = 2,
      "wire-limit failure left the sub-block writer retryable");

   Storage := [others => 0];
   Giflib.Streams.Open (Destination);
   Giflib.Internal.Blocks.Initialize
     (Writer, Max_Payload_Bytes => 1, Max_Wire_Bytes => 3);
   Outcome := Giflib.Internal.Blocks.Write_Data (Writer, Destination, [1 => 42]);
   Assert (Giflib.Results.Succeeded (Outcome), "writer rejected bounded payload");
   Outcome := Giflib.Internal.Blocks.Finish (Writer, Destination);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Storage = [1, 42, 0]
      and then Giflib.Internal.Blocks.Total_Wire_Bytes (Writer) = 3,
      "writer did not account for the final block and terminator");

   Giflib.Streams.Open (Short_Destination);
   Giflib.Internal.Blocks.Initialize
     (Writer, Max_Payload_Bytes => 1, Max_Wire_Bytes => 3);
   Outcome := Giflib.Internal.Blocks.Write_Data
     (Writer, Short_Destination, [1 => 42]);
   Assert (Giflib.Results.Succeeded (Outcome), "short writer setup failed");
   Outcome := Giflib.Internal.Blocks.Finish (Writer, Short_Destination);
   Assert
     (not Giflib.Results.Succeeded (Outcome)
      and then Short_Destination.Offset = 1,
      "short destination did not fail after writing the block prefix");
   Outcome := Giflib.Internal.Blocks.Finish (Writer, Short_Destination);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
      and then Short_Destination.Offset = 1,
      "failed sub-block writer accepted a retry or duplicated output");
end Writer_Enforces_Wire_Limit;
