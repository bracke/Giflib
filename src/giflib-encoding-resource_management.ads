with Giflib.Internal.Cleanup;

private package Giflib.Encoding.Resource_Management is
   pragma Preelaborate;

   function Release
     (Resources : in out Encoder_Resources)
      return Internal.Cleanup.Cleanup_Outcome;
   function Release (Object : in out Encoder) return Quantization.Cleanup_Status;

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
