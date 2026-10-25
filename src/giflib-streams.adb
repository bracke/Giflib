with Giflib.Internal.Stream_Arithmetic;
with Giflib.Internal.Stream_Dispatch;
with Giflib.Internal.Stream_Transfers;

package body Giflib.Streams is
   package Arithmetic renames Giflib.Internal.Stream_Arithmetic;

   function Position (Object : Source'Class) return Source_Position_Result is
     (Internal.Stream_Dispatch.Position (Object));

   function Position
     (Object : Source'Class;
      Rewind : Source_Offset) return Source_Position_Result
   is (Internal.Stream_Dispatch.Position (Object, Rewind));

   function Position
     (Object : Destination'Class) return Destination_Position_Result
   is (Internal.Stream_Dispatch.Position (Object));

   function Read_Some_At
     (Object : in out Source'Class;
      Buffer : out Byte_Array;
      Start : out Source_Position_Result) return Source_Result
   is (Internal.Stream_Dispatch.Read_Some (Object, Buffer, Start));

   function Read_Some
     (Object : in out Source'Class;
      Buffer : out Byte_Array) return Source_Result
   is
      Start : Source_Position_Result;
   begin
      return Read_Some_At (Object, Buffer, Start);
   end Read_Some;

   function Skip_Some_At
     (Object : in out Source'Class;
      Count : Byte_Count;
      Start : out Source_Position_Result) return Source_Result
   is (Internal.Stream_Dispatch.Skip_Some (Object, Count, Start));

   function Skip_Some
     (Object : in out Source'Class;
      Count : Byte_Count) return Source_Result
   is
      Start : Source_Position_Result;
   begin
      return Skip_Some_At (Object, Count, Start);
   end Skip_Some;

   function Write_Some_At
     (Object : in out Destination'Class;
      Buffer : Byte_Array;
      Start : out Destination_Position_Result) return Destination_Result
   is (Internal.Stream_Dispatch.Write_Some (Object, Buffer, Start));

   function Write_Some
     (Object : in out Destination'Class;
      Buffer : Byte_Array) return Destination_Result
   is
      Start : Destination_Position_Result;
   begin
      return Write_Some_At (Object, Buffer, Start);
   end Write_Some;

   function Flush_Safely
     (Object : in out Destination'Class) return Errors.Error
   is (Internal.Stream_Dispatch.Flush (Object));

   function Read_Exact
     (Object : in out Source'Class;
      Buffer : out Byte_Array) return Results.Result
   is (Internal.Stream_Transfers.Read_Exact (Object, Buffer));

   function Skip_Exact
     (Object : in out Source'Class;
      Count : Byte_Count) return Results.Result
   is (Internal.Stream_Transfers.Skip_Exact (Object, Count));

   function Write_All
     (Object : in out Destination'Class;
      Buffer : Byte_Array;
      Count : out Byte_Count) return Results.Result
   is (Internal.Stream_Transfers.Write_All (Object, Buffer, Count));

   function Write_All
     (Object : in out Destination'Class;
      Buffer : Byte_Array) return Results.Result
   is
      Count : Byte_Count;
   begin
      return Write_All (Object, Buffer, Count);
   end Write_All;

   procedure Open
     (Object : in out Memory_Source;
      Max_Transfer : Byte_Count := Byte_Count'Last)
   is
   begin
      Object.Position := 0;
      Object.Max_Transfer := Max_Transfer;
   end Open;

   overriding function Read (Object : in out Memory_Source; Buffer : out Byte_Array) return Source_Result is
      Plan : Arithmetic.Transfer_Plan;
      To_Copy : Natural;
   begin
      Plan := Arithmetic.Plan_Transfer
        (Object.Position, Object.Storage'Length, Buffer'Length, Object.Max_Transfer);
      To_Copy := Plan.Count;

      if To_Copy > 0 then
         for I in 0 .. To_Copy - 1 loop
            Buffer (Buffer'First + I) := Object.Storage (Object.Storage'First + Object.Position + I);
         end loop;
      end if;

      Object.Position := Plan.Next_Position;
      return
        (Error => Errors.Make (Errors.No_Error),
         Count => Byte_Count (To_Copy),
         End_Of_Input => Object.Position = Object.Storage'Length);
   end Read;

   overriding function Offset (Object : Memory_Source) return Source_Offset is
   begin
      return Source_Offset (Object.Position);
   end Offset;

   overriding function Skip (Object : in out Memory_Source; Count : Byte_Count) return Source_Result is
      Plan : Arithmetic.Transfer_Plan;
      To_Skip : Natural;
   begin
      Plan := Arithmetic.Plan_Transfer
        (Object.Position,
         Object.Storage'Length,
         Arithmetic.Cap_To_Natural (Count),
         Object.Max_Transfer);
      To_Skip := Plan.Count;
      Object.Position := Plan.Next_Position;
      return
        (Error => Errors.Make (Errors.No_Error),
         Count => Byte_Count (To_Skip),
         End_Of_Input => Object.Position = Object.Storage'Length);
   end Skip;

   procedure Open
     (Object : in out Fixed_Buffer_Destination;
      Max_Transfer : Byte_Count := Byte_Count'Last)
   is
   begin
      Object.Position := 0;
      Object.Max_Transfer := Max_Transfer;
   end Open;

   overriding function Write
     (Object : in out Fixed_Buffer_Destination; Buffer : Byte_Array) return Destination_Result
   is
      Plan : Arithmetic.Transfer_Plan;
      To_Copy : Natural;
   begin
      Plan := Arithmetic.Plan_Transfer
        (Object.Position, Object.Storage'Length, Buffer'Length, Object.Max_Transfer);
      To_Copy := Plan.Count;

      if To_Copy > 0 then
         for I in 0 .. To_Copy - 1 loop
            Object.Storage (Object.Storage'First + Object.Position + I) := Buffer (Buffer'First + I);
         end loop;
      end if;
      Object.Position := Plan.Next_Position;

      if To_Copy < Buffer'Length and then To_Copy = Plan.Available then
         return
           (Error => Errors.Make
              (Errors.Limit_Exceeded,
               (Destination_Position => Errors.Destination_Position_At (Destination_Offset (Object.Position)),
                Expected => Byte_Count (Buffer'Length),
                Actual => Byte_Count (To_Copy),
                Limit => Output_Byte_Limit,
                others => <>)),
            Count => Byte_Count (To_Copy));
      end if;

      return (Error => Errors.Make (Errors.No_Error), Count => Byte_Count (To_Copy));
   end Write;

   overriding function Offset (Object : Fixed_Buffer_Destination) return Destination_Offset is
   begin
      return Destination_Offset (Object.Position);
   end Offset;

   overriding function Flush (Object : in out Fixed_Buffer_Destination) return Errors.Error is
      pragma Unreferenced (Object);
   begin
      return Errors.Make (Errors.No_Error);
   end Flush;
end Giflib.Streams;
