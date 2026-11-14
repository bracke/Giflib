separate (Giflib.Testing.Test_Blocks)
procedure Truncation_And_Limits_Fail (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Truncated : aliased constant Giflib.Streams.Byte_Array := [3, 1, 2];
   Oversized : aliased constant Giflib.Streams.Byte_Array := [3, 1, 2, 3, 0];
   Source : Giflib.Streams.Memory_Source (Truncated'Access);
   Oversized_Source : Giflib.Streams.Memory_Source (Oversized'Access);
   Reader : Giflib.Internal.Blocks.Sub_Block_Reader;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 10, Giflib.Compressed_Byte_Limit, Giflib.Image_Data_Block);
   Outcome := Giflib.Internal.Blocks.Drain (Reader, Source);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block, "truncation has wrong error");
   Assert (Outcome.First_Error.Context.Block = Giflib.Image_Data_Block,
           "truncation lost block context");

   Giflib.Streams.Open (Oversized_Source);
   Giflib.Internal.Blocks.Initialize
     (Reader, 2, Giflib.Per_Extension_Byte_Limit, Giflib.Comment_Extension_Block);
   Outcome := Giflib.Internal.Blocks.Drain (Reader, Oversized_Source);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "oversized chain was accepted");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Per_Extension_Byte_Limit,
           "oversized chain lost limit context");
   Assert (Oversized_Source.Offset = 1, "oversized payload was read before rejection");
   declare
      Failed_Offset : constant Giflib.Source_Offset := Oversized_Source.Offset;
   begin
      Outcome := Giflib.Internal.Blocks.Drain (Reader, Oversized_Source);
      Assert
        (Outcome.First_Error.Code = Giflib.Errors.Invalid_State
         and then Oversized_Source.Offset = Failed_Offset,
         "failed sub-block reader accepted a retry or consumed input");
   end;
end Truncation_And_Limits_Fail;
