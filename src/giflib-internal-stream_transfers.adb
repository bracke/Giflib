with Giflib.Errors;
with Giflib.Internal.Stream_Arithmetic;
with Giflib.Internal.Stream_Dispatch;

package body Giflib.Internal.Stream_Transfers is
   package Arithmetic renames Stream_Arithmetic;
   package Dispatch renames Stream_Dispatch;

   function Read_Exact
     (Object : in out Streams.Source'Class;
      Buffer : out Streams.Byte_Array) return Results.Result
   is
      Completed : Natural := 0;
   begin
      while Completed < Buffer'Length loop
         declare
            Step : Streams.Source_Result;
            Remaining : constant Natural := Buffer'Length - Completed;
            Current : Streams.Source_Position_Result;
         begin
            Step := Dispatch.Read_Some
              (Object, Buffer (Buffer'First + Completed .. Buffer'Last), Current);
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Source_Position => Dispatch.Source_Context (Current),
                      Expected => Byte_Count (Remaining), Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               return Results.Failure
                 (Errors.Make
                    ((if Step.End_Of_Input then Errors.Source_Unexpected_End
                      else Errors.Source_Zero_Progress),
                     (Source_Position => Dispatch.Source_Context (Current),
                      Expected => (if Step.End_Of_Input
                                   then Byte_Count (Buffer'Length) else 0),
                      Actual => (if Step.End_Of_Input
                                 then Byte_Count (Completed) else 0),
                      others => <>)));
            end if;
            Completed := Arithmetic.Advance_Natural
              (Completed, Buffer'Length, Step.Count);
         end;
      end loop;
      return Results.Success;
   end Read_Exact;

   function Skip_Exact
     (Object : in out Streams.Source'Class;
      Count : Byte_Count) return Results.Result
   is
      Completed : Byte_Count := 0;
   begin
      while Completed < Count loop
         declare
            Remaining : constant Byte_Count := Count - Completed;
            Step : Streams.Source_Result;
            Current : Streams.Source_Position_Result;
         begin
            Step := Dispatch.Skip_Some (Object, Remaining, Current);
            if Errors.Is_Fatal (Step.Error) then
               return Results.Failure (Step.Error);
            elsif not Arithmetic.Fits_Count_Remaining
              (Completed, Count, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Source_Position => Dispatch.Source_Context (Current),
                      Expected => Remaining, Actual => Step.Count,
                      others => <>)));
            elsif Step.Count = 0 then
               return Results.Failure
                 (Errors.Make
                    ((if Step.End_Of_Input then Errors.Source_Unexpected_End
                      else Errors.Source_Zero_Progress),
                     (Source_Position => Dispatch.Source_Context (Current),
                      Expected => (if Step.End_Of_Input then Count else 0),
                      Actual => (if Step.End_Of_Input then Completed else 0),
                      others => <>)));
            end if;
            Completed := Arithmetic.Advance_Count (Completed, Count, Step.Count);
         end;
      end loop;
      return Results.Success;
   end Skip_Exact;

   function Write_All
     (Object : in out Streams.Destination'Class;
      Buffer : Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Completed : Natural := 0;
   begin
      Count := 0;
      while Completed < Buffer'Length loop
         declare
            Remaining : constant Natural := Buffer'Length - Completed;
            Step : Streams.Destination_Result;
            Current : Streams.Destination_Position_Result;
         begin
            Step := Dispatch.Write_Some
              (Object, Buffer (Buffer'First + Completed .. Buffer'Last), Current);
            if not Arithmetic.Fits_Natural_Remaining
              (Completed, Buffer'Length, Step.Count)
            then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Destination_Position => Dispatch.Destination_Context (Current),
                      Expected => Byte_Count (Remaining), Actual => Step.Count,
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
                     (Destination_Position => Dispatch.Destination_Context (Current),
                      others => <>)));
            end if;
         end;
      end loop;
      return Results.Success;
   end Write_All;
end Giflib.Internal.Stream_Transfers;
