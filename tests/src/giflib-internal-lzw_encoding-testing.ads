with Giflib.Internal.Interlacing;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Encoding.Testing is
   type Workspace is limited private;

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
        Interlacing.Sequential_Layout) return Results.Result;

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
        Interlacing.Sequential_Layout) return Results.Result;

private
   type Workspace is limited record
      Value : Giflib.Internal.LZW_Encoding.Workspace;
   end record;
end Giflib.Internal.LZW_Encoding.Testing;
