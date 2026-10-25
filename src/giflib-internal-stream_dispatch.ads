with Giflib.Errors;
with Giflib.Streams;

package Giflib.Internal.Stream_Dispatch
  with Preelaborate
is
   function Position
     (Object : Streams.Source'Class) return Streams.Source_Position_Result;
   function Position
     (Object : Streams.Source'Class;
      Rewind : Source_Offset) return Streams.Source_Position_Result;
   function Position
     (Object : Streams.Destination'Class)
      return Streams.Destination_Position_Result;

   function Source_Context
     (Position : Streams.Source_Position_Result)
      return Errors.Source_Position_Context;
   function Destination_Context
     (Position : Streams.Destination_Position_Result)
      return Errors.Destination_Position_Context;

   function Read_Some
     (Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array;
      Start : out Streams.Source_Position_Result) return Streams.Source_Result;
   function Skip_Some
     (Object : in out Streams.Source'Class;
      Count : Byte_Count;
      Start : out Streams.Source_Position_Result) return Streams.Source_Result;
   function Write_Some
     (Object : in out Streams.Destination'Class;
      Buffer : Streams.Byte_Array;
      Start : out Streams.Destination_Position_Result)
      return Streams.Destination_Result;
   function Flush (Object : in out Streams.Destination'Class)
      return Errors.Error;
end Giflib.Internal.Stream_Dispatch;
