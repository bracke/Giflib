private package Giflib.Internal.Blocks.Writer_Operations
  with Preelaborate
is
   procedure Initialize
     (Writer : in out Sub_Block_Writer;
      Max_Payload_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count);

   function Write_Data
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Results.Result;

   function Write_Data_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Write_Status;

   function Put_Byte_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Value : Byte) return Write_Status;
   pragma Inline_Always (Put_Byte_Validated);

   function Put_Two_Bytes_Validated
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      First, Second : Byte) return Write_Status;
   pragma Inline_Always (Put_Two_Bytes_Validated);

   function Finish
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result;
end Giflib.Internal.Blocks.Writer_Operations;
