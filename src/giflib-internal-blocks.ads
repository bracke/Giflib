with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.Blocks is
   pragma Preelaborate;

   type Sub_Block_Reader is limited private;

   procedure Initialize
     (Reader : in out Sub_Block_Reader;
      Max_Bytes : Byte_Count;
      Limit : Limit_Kind;
      Block : Block_Kind);

   function Read_Data
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array;
      Count : out Byte_Count;
      End_Of_Data : out Boolean) return Results.Result;

   function Drain
     (Reader : in out Sub_Block_Reader;
      Object : in out Streams.Source'Class) return Results.Result;

   function Total_Bytes (Reader : Sub_Block_Reader) return Byte_Count;
   function Finished (Reader : Sub_Block_Reader) return Boolean;

   type Sub_Block_Writer is limited private;
   procedure Initialize
     (Writer : in out Sub_Block_Writer;
      Max_Payload_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count);
   function Write_Data
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class;
      Data : Streams.Byte_Array) return Results.Result;
   function Finish
     (Writer : in out Sub_Block_Writer;
      Object : in out Streams.Destination'Class) return Results.Result;
   function Total_Payload_Bytes (Writer : Sub_Block_Writer) return Byte_Count;
   function Total_Wire_Bytes (Writer : Sub_Block_Writer) return Byte_Count;

private
   type Sub_Block_Reader is limited record
      Remaining : Natural range 0 .. 255 := 0;
      Total : Byte_Count := 0;
      Maximum : Byte_Count := 0;
      Applied_Limit : Limit_Kind := No_Limit;
      Owner_Block : Block_Kind := No_Block;
      At_End : Boolean := False;
   end record;

   type Sub_Block_Writer is limited record
      Buffer : Streams.Byte_Array (1 .. 255) := [others => 0];
      Used : Natural range 0 .. 255 := 0;
      Payload_Total : Byte_Count := 0;
      Wire_Total : Byte_Count := 0;
      Maximum_Payload : Byte_Count := 0;
      Maximum_Wire : Byte_Count := 0;
      Is_Finished : Boolean := False;
   end record;
end Giflib.Internal.Blocks;
