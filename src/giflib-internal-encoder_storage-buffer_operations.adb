with Giflib.Errors;
with Giflib.Internal.Owned_Buffers.Result_Operations;

package body Giflib.Internal.Encoder_Storage.Buffer_Operations is
   package Buffer_Results renames Owned_Buffers.Result_Operations;

   function Update_Truecolor
     (Object : in out Resources;
      Pixel_Count : Byte_Count;
      Process : not null access function
        (Pixels : in out Streams.Byte_Array) return Results.Result)
      return Results.Result
   is
      function Run
        (Pixels : in out Streams.Byte_Array) return Results.Result is
      begin
         return Process (Pixels (1 .. Natural (Pixel_Count)));
      end Run;
   begin
      if Pixel_Count = 0
        or else Pixel_Count > Byte_Count (Natural'Last)
        or else Truecolor_Length (Object) < Pixel_Count
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      return Buffer_Results.Update (Object.Truecolor_Buffer, Run'Access);
   end Update_Truecolor;

end Giflib.Internal.Encoder_Storage.Buffer_Operations;
