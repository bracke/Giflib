with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Frame_Compositing;
with Giflib.Decoding.Frame_Data;
with Giflib.Decoding.Session_Transitions;

package body Giflib.Decoding.Frame_Execution is
   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result
   is
      Decoded_Pixels : Pixel_Count := Object.Total_Decoded_Pixels;
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Frame_Data.Decode_Indices
        (Object, Output, Decoded_Pixels, Compressed_Bytes);
      Session_Transitions.Commit_Resource_Usage
        (Object, Decoded_Pixels, Compressed_Bytes);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Failure_Handling.Fail (Object, Outcome.First_Error));
   end Decode_Indices;

   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result is
   begin
      return Frame_Compositing.Composite (Object, Target);
   end Composite;

   function Skip_Data (Object : in out Decoder) return Results.Result
   is
      Compressed_Bytes : Byte_Count := Object.Total_Compressed_Bytes;
      Outcome : Results.Result;
   begin
      Outcome := Frame_Data.Skip (Object, Compressed_Bytes);
      Session_Transitions.Commit_Resource_Usage
        (Object, Object.Total_Decoded_Pixels, Compressed_Bytes);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Failure_Handling.Fail (Object, Outcome.First_Error));
   end Skip_Data;
end Giflib.Decoding.Frame_Execution;
