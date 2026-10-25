with Giflib.Errors;
with Giflib.Results;

package Giflib.Streams is
   pragma Preelaborate;

   type Byte_Array is array (Positive range <>) of Byte;

   type Source_Result is record
      Error : Errors.Error := Errors.Make (Errors.No_Error);
      Count : Byte_Count := 0;
      End_Of_Input : Boolean := False;
   end record;

   type Destination_Result is record
      Error : Errors.Error := Errors.Make (Errors.No_Error);
      Count : Byte_Count := 0;
   end record;

   type Source_Position_Result (Available : Boolean := False) is record
      case Available is
         when True =>
            Value : Source_Offset := 0;
         when False =>
            null;
      end case;
   end record;

   type Destination_Position_Result (Available : Boolean := False) is record
      case Available is
         when True =>
            Value : Destination_Offset := 0;
         when False =>
            null;
      end case;
   end record;

   type Source is limited interface;
   function Read (Object : in out Source; Buffer : out Byte_Array) return Source_Result is abstract;
   function Offset (Object : Source) return Source_Offset is abstract;
   function Skip (Object : in out Source; Count : Byte_Count) return Source_Result is abstract;

   type Destination is limited interface;
   function Write (Object : in out Destination; Buffer : Byte_Array) return Destination_Result is abstract;
   function Offset (Object : Destination) return Destination_Offset is abstract;
   function Flush (Object : in out Destination) return Errors.Error is abstract;

   --  These helpers complete a requested transfer across short reads/writes.
   --  They reject a successful zero-byte transfer because retrying it could hang.
   function Read_Exact (Object : in out Source'Class; Buffer : out Byte_Array) return Results.Result;
   function Skip_Exact (Object : in out Source'Class; Count : Byte_Count) return Results.Result;
   function Write_All (Object : in out Destination'Class; Buffer : Byte_Array) return Results.Result;
   function Write_All
     (Object : in out Destination'Class;
      Buffer : Byte_Array;
      Count : out Byte_Count) return Results.Result;
   --  Count includes every byte accepted by the destination, including bytes
   --  accepted by the final write call when that call also reports an error.
   function Read_Some
     (Object : in out Source'Class;
      Buffer : out Byte_Array) return Source_Result;
   function Skip_Some
     (Object : in out Source'Class;
      Count : Byte_Count) return Source_Result;
   function Write_Some
     (Object : in out Destination'Class;
      Buffer : Byte_Array) return Destination_Result;
   function Flush_Safely
     (Object : in out Destination'Class) return Errors.Error;
   function Position (Object : Source'Class) return Source_Position_Result;
   function Position
     (Object : Source'Class;
      Rewind : Source_Offset) return Source_Position_Result;
   function Position
     (Object : Destination'Class) return Destination_Position_Result;

   type Memory_Source
     (Storage : not null access constant Byte_Array)
      is limited new Source with private;
   procedure Open
     (Object : in out Memory_Source;
      Max_Transfer : Byte_Count := Byte_Count'Last);
   overriding function Read (Object : in out Memory_Source; Buffer : out Byte_Array) return Source_Result;
   overriding function Offset (Object : Memory_Source) return Source_Offset;
   overriding function Skip (Object : in out Memory_Source; Count : Byte_Count) return Source_Result;

   type Fixed_Buffer_Destination
     (Storage : not null access Byte_Array)
      is limited new Destination with private;
   procedure Open
     (Object : in out Fixed_Buffer_Destination;
      Max_Transfer : Byte_Count := Byte_Count'Last);
   overriding function Write
     (Object : in out Fixed_Buffer_Destination; Buffer : Byte_Array) return Destination_Result;
   overriding function Offset (Object : Fixed_Buffer_Destination) return Destination_Offset;
   overriding function Flush (Object : in out Fixed_Buffer_Destination) return Errors.Error;

private
   type Memory_Source
     (Storage : not null access constant Byte_Array)
      is limited new Source with record
      Position : Natural := 0;
      Max_Transfer : Byte_Count := Byte_Count'Last;
   end record;

   type Fixed_Buffer_Destination
     (Storage : not null access Byte_Array)
      is limited new Destination with record
      Position : Natural := 0;
      Max_Transfer : Byte_Count := Byte_Count'Last;
   end record;
end Giflib.Streams;
