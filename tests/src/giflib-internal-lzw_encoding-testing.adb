package body Giflib.Internal.LZW_Encoding.Testing is
   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Wire_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout) return Results.Result
   is
      Parameters : constant Giflib.Internal.LZW_Encoding.Encode_Parameters :=
        (Minimum_Code_Size => Minimum_Code_Size,
         Max_Work => Max_Work,
         Max_Compressed_Bytes => Max_Compressed_Bytes,
         Max_Wire_Bytes => Max_Wire_Bytes,
         Maximum_Index => Maximum_Index,
         Layout => Layout);
      Statistics : Giflib.Internal.LZW_Encoding.Encode_Statistics;
      Outcome : Results.Result;
   begin
      Outcome := Giflib.Internal.LZW_Encoding.Encode
        (Context.Value, Object, Input, Parameters, Statistics);
      Compressed_Bytes := Statistics.Compressed_Bytes;
      Wire_Bytes := Statistics.Wire_Bytes;
      return Outcome;
   end Encode;

   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Layout : Interlacing.Traversal_Layout :=
        Interlacing.Sequential_Layout) return Results.Result
   is
      Wire_Bytes : Byte_Count;
   begin
      return Encode
        (Context, Object, Input, Minimum_Code_Size, Max_Work,
         Max_Compressed_Bytes, Max_Wire_Bytes, Compressed_Bytes, Wire_Bytes,
         Maximum_Index, Layout);
   end Encode;
end Giflib.Internal.LZW_Encoding.Testing;
