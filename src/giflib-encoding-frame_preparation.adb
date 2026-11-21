with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Request_Validation;
with Giflib.Internal.Encoding_Arithmetic;

package body Giflib.Encoding.Frame_Preparation is
   package Encoding_Arithmetic renames Giflib.Internal.Encoding_Arithmetic;

   function Validate
     (Object : Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : out Prepared_Frame_Request) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Data := (others => <>);
      Outcome := Request_Validation.Validate_Frame (Object, Info);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Reject_Frame (Object, Outcome.First_Error);
      end if;
      if Palette.Selection = Use_Local_Palette then
         Data.Effective := Palette.Value;
      elsif Object.Global_Palette.Present then
         Data.Effective := Object.Global_Palette.Value;
      else
         return Failure_Handling.Reject_Frame
           (Object, Errors.Make (Errors.Missing_Color_Table));
      end if;
      if Data.Effective.Length < 2 then
         return Failure_Handling.Reject_Frame
           (Object, Errors.Make (Errors.Missing_Color_Table));
      elsif Info.Control.Has_Transparency
        and then not Palettes.Contains
          (Data.Effective, Info.Control.Transparent_Index)
      then
         return Failure_Handling.Reject_Frame
           (Object, Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      Data.Minimum := Byte
        (Encoding_Arithmetic.Minimum_LZW_Code_Size
           (Encoding_Arithmetic.Encoded_Palette_Length
              (Encoding_Arithmetic.Palette_Length (Data.Effective.Length))));
      return Results.Success;
   end Validate;
end Giflib.Encoding.Frame_Preparation;
