private package Giflib.Encoding.Failure_Handling is
   pragma Preelaborate;

   function Invalid_State (Object : Encoder) return Results.Result;
   function Fail
     (Object : in out Encoder; Item : Errors.Error) return Results.Result;
   function Reject
     (Object : Encoder; Item : Errors.Error) return Results.Result;
   function Reject_Frame
     (Object : Encoder; Item : Errors.Error) return Results.Result;
   function Fail_Frame_Request
     (Object : in out Encoder; Item : Errors.Error) return Results.Result;
end Giflib.Encoding.Failure_Handling;
