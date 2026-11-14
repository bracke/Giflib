with Giflib.Encoding.Session_Transitions;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Container_Writer;
with Giflib.Internal.Diagnostics;

package body Giflib.Encoding.Wire_Output is
   function Write
     (Object : in out Encoder; Data : Streams.Byte_Array)
      return Results.Result
   is
      Outcome : Results.Result;
      Written : Byte_Count;
      Budget : constant Internal.Budget_Arithmetic.Charge_Result :=
        Internal.Budget_Arithmetic.Charge
          (Object.Bytes_Written, Object.Constraints.Max_Output_Bytes,
           Byte_Count (Data'Length));
   begin
      if not Budget.Accepted then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Destination
                 (Object.Output.all,
                  (Expected => Object.Constraints.Max_Output_Bytes,
                   Actual => Budget.Attempted,
                   Limit => Output_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Streams.Write_All (Object.Output.all, Data, Written);
      Session_Transitions.Record_Wire_Bytes (Object, Written);
      return Outcome;
   end Write;

   function Write_Color_Table
     (Object : in out Encoder; Palette : Palettes.Palette)
      return Results.Result
   is
     (Write (Object, Internal.Container_Writer.Palette_Data (Palette)));
end Giflib.Encoding.Wire_Output;
