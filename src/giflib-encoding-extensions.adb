with Giflib.Encoding.Extensions.Emission;
with Giflib.Encoding.Extensions.Validation;
with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Session_Transitions;
with Giflib.Encoding.Wire_Output;

package body Giflib.Encoding.Extensions is
   function Complete_Extension
     (Object : in out Encoder;
      Outcome : Results.Result) return Results.Result
   is
      Final_Outcome : Results.Result := Outcome;
   begin
      if Results.Succeeded (Final_Outcome) then
         Final_Outcome := Wire_Output.Write (Object, [1 => 0]);
      end if;
      if not Results.Succeeded (Final_Outcome) then
         return Failure_Handling.Fail (Object, Final_Outcome.First_Error);
      end if;
      Session_Transitions.Complete_Extension (Object);
      return Results.Success;
   end Complete_Extension;

   function Write_Extension
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Plan : Chunk_Plan) return Results.Result
   is
      Fixed_Length : Natural;
      Outcome : Results.Result;
   begin
      Outcome := Validation.Request
        (Object, Descriptor, Payload, Fixed_Length);
      if Results.Succeeded (Outcome) then
         Outcome := Validation.Chunking (Payload, Fixed_Length, Plan);
      end if;
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Reject (Object, Outcome.First_Error);
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Emission.Emit
           (Object, Descriptor, Payload, Fixed_Length, Plan);
      end if;
      return Complete_Extension (Object, Outcome);
   end Write_Extension;

   function Add
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result is
   begin
      return Write_Extension
        (Object, Descriptor, Payload,
         (Kind => Automatic_Chunks, Count => 0));
   end Add;

   function Add_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
      Plan : constant Chunk_Plan :=
        (Kind => Exact_Chunks,
         Count => Chunk_Lengths'Length,
         Lengths => Chunk_Lengths);
   begin
      return Write_Extension (Object, Descriptor, Payload, Plan);
   end Add_Exact;
end Giflib.Encoding.Extensions;
