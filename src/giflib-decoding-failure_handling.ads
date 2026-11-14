private package Giflib.Decoding.Failure_Handling is
   pragma Preelaborate;

   function Input_Position_Of
     (Object : Decoder) return Streams.Source_Position_Result;
   function Invalid_State (Object : Decoder) return Results.Result;
   function Fail
     (Object : in out Decoder; Item : Errors.Error) return Results.Result;
   function Variant_Error
     (Object : Decoder; Expected : Natural; Actual : Natural)
      return Errors.Error;
   procedure Record_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>));
end Giflib.Decoding.Failure_Handling;
