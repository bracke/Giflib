private package Giflib.Encoding.Request_Validation is
   pragma Preelaborate;

   function Has_Extension_Room
     (Object : Encoder; Additional : Natural) return Boolean;
   function Validate_Screen
     (Object : Encoder; Screen : Screen_Info) return Results.Result;
   function Validate_Global_Palette
     (Object : Encoder; Palette : Palettes.Palette) return Results.Result;
   function Validate_Loop_Count
     (Object : Encoder; Count : Natural) return Results.Result;
   function Validate_Frame
     (Object : Encoder; Info : Frame_Info) return Results.Result;
end Giflib.Encoding.Request_Validation;
