with Giflib.Internal.Stream_Arithmetic;

package body Giflib.Streams is
   use type Errors.Position_State;
   package Arithmetic renames Giflib.Internal.Stream_Arithmetic;

   function Source_Context
     (Position : Source_Position_Result) return Errors.Source_Position_Context is
     (if Position.Available
      then Errors.Source_Position_At (Position.Value)
      else (State => Errors.Position_Unavailable));

   function Destination_Context
     (Position : Destination_Position_Result)
      return Errors.Destination_Position_Context is
     (if Position.Available
      then Errors.Destination_Position_At (Position.Value)
      else (State => Errors.Position_Unavailable));

   function At_Source
     (Item : Errors.Error;
      Position : Source_Position_Result) return Errors.Error
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Source_Position.State = Errors.Position_Not_Checked then
         Enriched.Context.Source_Position := Source_Context (Position);
      end if;
      return Enriched;
   end At_Source;

   function At_Destination
     (Item : Errors.Error;
      Position : Destination_Position_Result) return Errors.Error
   is
      Enriched : Errors.Error := Item;
   begin
      if Enriched.Context.Destination_Position.State = Errors.Position_Not_Checked
      then
         Enriched.Context.Destination_Position := Destination_Context (Position);
      end if;
      return Enriched;
   end At_Destination;

   function Position (Object : Source'Class) return Source_Position_Result is
   begin
      return (Available => True, Value => Object.Offset);
   exception
      when others =>
         return (Available => False);
   end Position;

   function Position
     (Object : Source'Class;
      Rewind : Source_Offset) return Source_Position_Result
   is
      Current : constant Source_Position_Result := Position (Object);
   begin
      if not Current.Available or else Current.Value < Rewind then
         return (Available => False);
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
         return (Available => False);
   end Position;

   function Read_Some_At
     (Object : in out Source'Class;
      Buffer : out Byte_Array;
      Start : out Source_Position_Result) return Source_Result
   is
      Result : Source_Result;
   begin
      Start := Position (Object);
      Result := Object.Read (Buffer);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Source (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return
           (Error => At_Source (Errors.Make (Errors.Source_Read_Failed), Start),
            Count => 0,
            End_Of_Input => False);
   end Read_Some_At;

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
   is
      Result : Source_Result;
   begin
      Start := Position (Object);
      Result := Object.Skip (Count);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Source (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return
           (Error => At_Source (Errors.Make (Errors.Source_Read_Failed), Start),
            Count => 0,
            End_Of_Input => False);
   end Skip_Some_At;

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
   is
      Result : Destination_Result;
   begin
      Start := Position (Object);
      Result := Object.Write (Buffer);
      if Errors.Is_Fatal (Result.Error) then
         Result.Error := At_Destination (Result.Error, Start);
      end if;
      return Result;
   exception
      when others =>
         return
           (Error => At_Destination
              (Errors.Make (Errors.Destination_Write_Failed), Start),
            Count => 0);
   end Write_Some_At;

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
   is
      Start : constant Destination_Position_Result := Position (Object);
      Result : Errors.Error;
   begin
      Result := Object.Flush;
      if Errors.Is_Fatal (Result) then
         Result := At_Destination (Result, Start);
      end if;
      return Result;
   exception
      when others =>
         return At_Destination
           (Errors.Make (Errors.Destination_Write_Failed), Start);
   end Flush_Safely;

   function Read_Exact (Object : in out Source'Class; Buffer : out Byte_Array) return Results.Result is
      Completed : Natural := 0;
   begin
      while Completed < Buffer'Length loop
         declare
            Step : Source_Result;
            Remaining : constant Natural := Buffer'Length - Completed;
            Current : Source_Position_Result;
         begin
            Step := Read_Some_At
              (Object,
               Buffer (Buffer'First + Completed .. Buffer'Last),
               Current);
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Source_Position => Source_Context (Current),
                      Expected => Byte_Count (Remaining),
                      Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               if Step.End_Of_Input then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Unexpected_End,
                        (Source_Position => Source_Context (Current),
                         Expected => Byte_Count (Buffer'Length),
                         Actual => Byte_Count (Completed),
                         others => <>)));
               else
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Zero_Progress,
                        (Source_Position => Source_Context (Current),
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
            Step : Source_Result;
            Current : Source_Position_Result;
         begin
            Step := Skip_Some_At (Object, Remaining, Current);
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Count_Remaining
              (Completed, Count, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Source_Position => Source_Context (Current),
                      Expected => Remaining,
                      Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               if Step.End_Of_Input then
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Unexpected_End,
                        (Source_Position => Source_Context (Current),
                         Expected => Count,
                         Actual => Completed,
                         others => <>)));
               else
                  return Results.Failure
                    (Errors.Make
                       (Errors.Source_Zero_Progress,
                        (Source_Position => Source_Context (Current),
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

   function Write_All
     (Object : in out Destination'Class;
      Buffer : Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Completed : Natural := 0;
   begin
      Count := 0;
      while Completed < Buffer'Length loop
         declare
            Step : Destination_Result;
            Remaining : constant Natural := Buffer'Length - Completed;
            Write_Position : Errors.Destination_Position_Context;
            Current : Destination_Position_Result;
         begin
            Step := Write_Some_At
              (Object,
               Buffer (Buffer'First + Completed .. Buffer'Last),
               Current);
            Write_Position := Destination_Context (Current);
            if not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Destination_Position => Write_Position,
                      Expected => Byte_Count (Remaining),
                      Actual => Step.Count,
                      others => <>)));
            end if;
            if Step.Count > 0 then
               Completed := Arithmetic.Advance_Natural
                 (Completed, Buffer'Length, Step.Count);
            end if;
            Count := Byte_Count (Completed);
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif Step.Count = 0 then
               return Results.Failure
                 (Errors.Make
                    (Errors.Destination_Zero_Progress,
                     (Destination_Position => Write_Position,
                      others => <>)));
            end if;
         end;
      end loop;
      return Results.Success;
   end Write_All;

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
