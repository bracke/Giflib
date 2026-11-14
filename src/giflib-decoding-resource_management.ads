with Giflib.Internal.Cleanup;

private package Giflib.Decoding.Resource_Management is
   pragma Preelaborate;

   function Release
     (Resources : in out Decoder_Resources)
      return Internal.Cleanup.Cleanup_Outcome;
   function Release
     (Object : in out Decoder) return Internal.Cleanup.Cleanup_Outcome;

   function Ensure_Frame_Scratch
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result;
   function Ensure_LZW_Workspace
     (Object : in out Decoder) return Results.Result;
   function Ensure_Snapshot
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result;
   function Ensure_Canvas
     (Object : in out Decoder;
      Required : Byte_Count) return Results.Result;
end Giflib.Decoding.Resource_Management;
