with Giflib.Internal.Blocks.Reader_Operations;
with Giflib.Internal.Blocks.Writer_Operations;

package body Giflib.Internal.Blocks is
   package Readers renames Giflib.Internal.Blocks.Reader_Operations;
   package Writers renames Giflib.Internal.Blocks.Writer_Operations;

   procedure Initialize
     (Reader : in out Sub_Block_Reader;
      Max_Bytes : Byte_Count;
      Limit : Limit_Kind;
      Block : Block_Kind) is
   begin
      Readers.Initialize (Reader, Max_Bytes, Limit, Block);
   end Initialize;

   function Read_Data
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array;
      Count : out Byte_Count;
      End_Of_Data : out Boolean) return Results.Result is
     (Readers.Read_Data
        (Reader, Object, Buffer, Count, End_Of_Data));

   function Drain
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class) return Results.Result is
     (Readers.Drain (Reader, Object));

   function Total_Bytes (Reader : Sub_Block_Reader) return Byte_Count is
     (Reader.Total);

   function Finished (Reader : Sub_Block_Reader) return Boolean is
     (Reader.State = Read_Finished);

   procedure Initialize
     (Writer : in out Sub_Block_Writer;
      Max_Payload_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count) is
   begin
      Writers.Initialize (Writer, Max_Payload_Bytes, Max_Wire_Bytes);
   end Initialize;

   function Write_Data
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Results.Result is
     (Writers.Write_Data (Writer, Object, Data));

   function Finish
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result is
     (Writers.Finish (Writer, Object));

   function Total_Payload_Bytes (Writer : Sub_Block_Writer) return Byte_Count is
     (Writer.Payload_Total);

   function Total_Payload_Written
     (Writer : Sub_Block_Writer) return Byte_Count is
     (Writer.Payload_Written);

   function Total_Wire_Bytes (Writer : Sub_Block_Writer) return Byte_Count is
     (Writer.Wire_Total);
end Giflib.Internal.Blocks;
