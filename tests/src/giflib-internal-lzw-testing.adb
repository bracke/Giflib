package body Giflib.Internal.LZW.Testing is
   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout) return Results.Result is
   begin
      return Giflib.Internal.LZW.Decode
        (Context.Value, Object, Blocks_Reader, Output, Decoded_Count,
         (Minimum_Code_Size => Minimum_Code_Size,
          Max_Work => Max_Work,
          Frame => Frame,
          Maximum_Index => Maximum_Index,
          Layout => Layout));
   end Decode;
end Giflib.Internal.LZW.Testing;
