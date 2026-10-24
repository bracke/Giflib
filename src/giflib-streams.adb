with Giflib.Internal.Stream_Arithmetic;

package body Giflib.Streams is
   package Arithmetic renames Giflib.Internal.Stream_Arithmetic;

   function Position (Object : Source'Class) return Source_Position_Result is
   begin
      return (Available => True, Value => Object.Offset);
   exception
      when others =>
         return (Available => False, Value => 0);
   end Position;

   function Position
     (Object : Source'Class;
      Rewind : Source_Offset) return Source_Position_Result
   is
      Current : constant Source_Position_Result := Position (Object);
   begin
      if not Current.Available or else Current.Value < Rewind then
         return (Available => False, Value => 0);
      end if;
      return (Available => True, Value => Current.Value - Rewind);
   end Position;

   function Position
     (Object : Destination'Class) return Destination_Position_Result
   is
   begin
      return (Available => True, Value => Object.Offset);
   exception
      when others =>
         return (Available => False, Value => 0);
   end Position;

   function Read_Some
     (Object : in out Source'Class;
      Buffer : out Byte_Array) return Source_Result
   is
   begin
      return Object.Read (Buffer);
   exception
      when others =>
         return
           (Error => Errors.Make (Errors.Source_Read_Failed),
            Count => 0,
            End_Of_Input => False);
   end Read_Some;

   function Skip_Some
     (Object : in out Source'Class;
      Count : Byte_Count) return Source_Result
   is
   begin
      return Object.Skip (Count);
   exception
      when others =>
         return
           (Error => Errors.Make (Errors.Source_Read_Failed),
            Count => 0,
            End_Of_Input => False);
   end Skip_Some;

   function Write_Some
     (Object : in out Destination'Class;
      Buffer : Byte_Array) return Destination_Result
   is
   begin
      return Object.Write (Buffer);
   exception
      when others =>
         return
           (Error => Errors.Make (Errors.Destination_Write_Failed),
            Count => 0);
   end Write_Some;

   function Flush_Safely
     (Object : in out Destination'Class) return Errors.Error
   is
   begin
      return Object.Flush;
   exception
      when others =>
         return Errors.Make (Errors.Destination_Write_Failed);
   end Flush_Safely;

   function Read_Exact (Object : in out Source'Class; Buffer : out Byte_Array) return Results.Result is
      Completed : Natural := 0;
   begin
      while Completed < Buffer'Length loop
         declare
            Step : constant Source_Result :=
              Read_Some
                (Object, Buffer (Buffer'First + Completed .. Buffer'Last));
            Remaining : constant Natural := Buffer'Length - Completed;
            Current : constant Source_Position_Result := Position (Object);
         begin
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Has_Source => Current.Available,
                      Source => Current.Value,
                      Expected => Byte_Count (Remaining),
                      Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               if Step.End_Of_Input then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Unexpected_End,
                        (Has_Source => Current.Available,
                         Source => Current.Value,
                         Expected => Byte_Count (Buffer'Length),
                         Actual => Byte_Count (Completed),
                         others => <>)));
               else
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Zero_Progress,
                        (Has_Source => Current.Available,
                         Source => Current.Value,
                         others => <>)));
               end if;
            else
               Completed := Arithmetic.Advance_Natural
                 (Completed, Buffer'Length, Step.Count);
            end if;
         end;
      end loop;
      return Results.Success;
   end Read_Exact;

   function Skip_Exact (Object : in out Source'Class; Count : Byte_Count) return Results.Result is
      Completed : Byte_Count := 0;
   begin
      while Completed < Count loop
         declare
            Remaining : constant Byte_Count := Count - Completed;
            Step : constant Source_Result := Skip_Some (Object, Remaining);
            Current : constant Source_Position_Result := Position (Object);
         begin
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Count_Remaining
              (Completed, Count, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Has_Source => Current.Available,
                      Source => Current.Value,
                      Expected => Remaining,
                      Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               if Step.End_Of_Input then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Unexpected_End,
                        (Has_Source => Current.Available,
                         Source => Current.Value,
                         Expected => Count,
                         Actual => Completed,
                         others => <>)));
               else
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Zero_Progress,
                        (Has_Source => Current.Available,
                         Source => Current.Value,
                         others => <>)));
               end if;
            else
               Completed := Arithmetic.Advance_Count
                 (Completed, Count, Step.Count);
            end if;
         end;
      end loop;
      return Results.Success;
   end Skip_Exact;

   function Write_All (Object : in out Destination'Class; Buffer : Byte_Array) return Results.Result is
      Completed : Natural := 0;
   begin
      while Completed < Buffer'Length loop
         declare
            Step : Destination_Result;
            Remaining : constant Natural := Buffer'Length - Completed;
            Write_Offset : Destination_Offset := 0;
            Has_Write_Offset : Boolean := False;
         begin
            declare
               Current : constant Destination_Position_Result := Position (Object);
            begin
               Write_Offset := Current.Value;
               Has_Write_Offset := Current.Available;
            end;
            Step := Write_Some
              (Object, Buffer (Buffer'First + Completed .. Buffer'Last));
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Has_Destination => Has_Write_Offset,
                      Destination => Write_Offset,
                      Expected => Byte_Count (Remaining),
                      Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               return Results.Failure
                 (Errors.Make
                    (Errors.Destination_Zero_Progress,
                     (Has_Destination => Has_Write_Offset,
                      Destination => Write_Offset,
                      others => <>)));
            else
               Completed := Arithmetic.Advance_Natural
                 (Completed, Buffer'Length, Step.Count);
            end if;
         end;
      end loop;
      return Results.Success;
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
               (Has_Destination => True, Destination => Destination_Offset (Object.Position),
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
