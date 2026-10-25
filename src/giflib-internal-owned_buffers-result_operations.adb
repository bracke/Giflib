package body Giflib.Internal.Owned_Buffers.Result_Operations is
   function Query
     (Buffer : in out Handle;
      Process : not null access function
        (Value : Streams.Byte_Array) return Results.Result)
      return Results.Result
   is
      Outcome : Results.Result;
      procedure Invoke (Value : Streams.Byte_Array) is
      begin
         Outcome := Process (Value);
      end Invoke;
   begin
      Owned_Buffers.Query (Buffer, Invoke'Access);
      return Outcome;
   end Query;

   function Update
     (Buffer : in out Handle;
      Process : not null access function
        (Value : in out Streams.Byte_Array) return Results.Result)
      return Results.Result
   is
      Outcome : Results.Result;
      procedure Invoke (Value : in out Streams.Byte_Array) is
      begin
         Outcome := Process (Value);
      end Invoke;
   begin
      Owned_Buffers.Update (Buffer, Invoke'Access);
      return Outcome;
   end Update;

   function Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access function
        (Source_Value : Streams.Byte_Array;
         Target_Value : in out Streams.Byte_Array) return Results.Result)
      return Results.Result
   is
      Outcome : Results.Result;
      procedure Invoke
        (Source_Value : Streams.Byte_Array;
         Target_Value : in out Streams.Byte_Array) is
      begin
         Outcome := Process (Source_Value, Target_Value);
      end Invoke;
   begin
      Owned_Buffers.Query_Update (Source, Target, Invoke'Access);
      return Outcome;
   end Query_Update;
end Giflib.Internal.Owned_Buffers.Result_Operations;
