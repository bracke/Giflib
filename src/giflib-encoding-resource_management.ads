private package Giflib.Encoding.Resource_Management is
   pragma Preelaborate;

   procedure Release (Resources : in out Encoder_Resources);
   procedure Release (Object : in out Encoder);

   function Ensure_Truecolor_Pixels
     (Object : in out Encoder;
      Required : Byte_Count) return Results.Result;

   function Ensure_LZW_Workspace
     (Object : in out Encoder) return Results.Result;

   function Quantization_Constraints
     (Object : Encoder) return Limits.Limit_Set;

   function Normalize_Quantization_Error
     (Object : Encoder;
      Item : Errors.Error) return Errors.Error;
end Giflib.Encoding.Resource_Management;
