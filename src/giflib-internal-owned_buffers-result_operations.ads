with Giflib.Results;

package Giflib.Internal.Owned_Buffers.Result_Operations is
   pragma Preelaborate;

   function Query
     (Buffer : in out Handle;
      Process : not null access function
        (Value : Streams.Byte_Array) return Results.Result)
      return Results.Result
     with Pre => Is_Allocated (Buffer) and then not Is_Borrowed (Buffer);

   function Update
     (Buffer : in out Handle;
      Process : not null access function
        (Value : in out Streams.Byte_Array) return Results.Result)
      return Results.Result
     with Pre => Is_Allocated (Buffer) and then not Is_Borrowed (Buffer);

   function Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access function
        (Source_Value : Streams.Byte_Array;
         Target_Value : in out Streams.Byte_Array) return Results.Result)
      return Results.Result
     with Pre => Is_Allocated (Source)
                 and then Is_Allocated (Target)
                 and then not Is_Borrowed (Source)
                 and then not Is_Borrowed (Target);
end Giflib.Internal.Owned_Buffers.Result_Operations;
