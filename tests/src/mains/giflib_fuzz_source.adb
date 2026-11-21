with Giflib.Errors;

package body Giflib_Fuzz_Source is
   use type Giflib.Byte_Count;

   overriding function Read
     (Object : in out Prefix_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is
      Available : constant Natural := Object.Length - Object.Position;
      Count : constant Natural :=
        Natural'Min (Available, Natural'Min (Buffer'Length, 3));
   begin
      for I in 0 .. Count - 1 loop
         Buffer (Buffer'First + I) :=
           Object.Storage (Object.Storage'First + Object.Position + I);
      end loop;
      Object.Position := Object.Position + Count;
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Count),
         End_Of_Input => Object.Position = Object.Length);
   end Read;

   overriding function Offset
     (Object : Prefix_Source) return Giflib.Source_Offset is
     (Giflib.Source_Offset (Object.Position));

   overriding function Skip
     (Object : in out Prefix_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      Available : constant Natural := Object.Length - Object.Position;
      Step : constant Natural :=
        (if Count < 3 then Natural (Count)
         else Natural'Min (Available, 3));
      Actual : constant Natural := Natural'Min (Available, Step);
   begin
      Object.Position := Object.Position + Actual;
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Actual),
         End_Of_Input => Object.Position = Object.Length);
   end Skip;
end Giflib_Fuzz_Source;
