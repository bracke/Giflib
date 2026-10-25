with Giflib.Errors;
with Giflib.Internal.Owned_Buffers.Result_Operations;

package body Giflib.Internal.Encoder_Storage.Frame_Operations is
   package Buffer_Results renames Owned_Buffers.Result_Operations;

   function Encode_LZW
     (Object : in out Resources;
      Destination : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Wire_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
   begin
      if not LZW_Allocated (Object) then
         Compressed_Bytes := 0;
         Wire_Bytes := 0;
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      return LZW_Encoding.Encode
        (Object.LZW_Data, Destination, Input, Minimum_Code_Size, Max_Work,
         Max_Compressed_Bytes, Max_Wire_Bytes, Compressed_Bytes, Wire_Bytes,
         Maximum_Index, Interlace_Width, Interlace_Height);
   end Encode_LZW;

   function Encode_Stored_LZW
     (Object : in out Resources;
      Destination : in out Streams.Destination'Class;
      Pixel_Count : Byte_Count;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Wire_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
   is
      function Run
        (Pixels : Streams.Byte_Array) return Results.Result is
      begin
         return LZW_Encoding.Encode
           (Object.LZW_Data,
            Destination,
            Pixels (1 .. Natural (Pixel_Count)),
            Minimum_Code_Size,
            Max_Work,
            Max_Compressed_Bytes,
            Max_Wire_Bytes,
            Compressed_Bytes,
            Wire_Bytes,
            Maximum_Index,
            Interlace_Width,
            Interlace_Height);
      end Run;
   begin
      if Pixel_Count = 0
        or else Pixel_Count > Byte_Count (Natural'Last)
        or else Truecolor_Length (Object) < Pixel_Count
      then
         Compressed_Bytes := 0;
         Wire_Bytes := 0;
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      if not LZW_Allocated (Object) then
         Compressed_Bytes := 0;
         Wire_Bytes := 0;
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      return Buffer_Results.Query (Object.Truecolor_Buffer, Run'Access);
   end Encode_Stored_LZW;
end Giflib.Internal.Encoder_Storage.Frame_Operations;
