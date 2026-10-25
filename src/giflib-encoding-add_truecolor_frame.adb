with Giflib.Internal.Encoder_Storage.Quantization_Operations;

separate (Giflib.Encoding)
function Add_Truecolor_Frame
  (Object : in out Encoder;
   Info : Frame_Info;
   Source : Images.Image_View;
   Options : Quantization.Quantize_Options := Quantization.Default_Options)
   return Results.Result
is
   Total : constant Byte_Count := Geometry_Arithmetic.Area (Info.Width, Info.Height);
   Quantized : Quantization.Quantization_Result;
   Quantize_Options : Quantization.Quantize_Options := Options;
   Adjusted : Frame_Info := Info;
   Selection : Palette_Selection := Use_Local_Palette;
   Outcome : Results.Result;

   function Add_Quantized
     (Pixels : Streams.Byte_Array) return Results.Result
   is (Add_Indexed_Frame
         (Object,
          Adjusted,
          (if Selection = Use_Local_Palette
           then (Selection => Use_Local_Palette, Value => Quantized.Palette)
           else Global_Frame_Palette),
          Pixels));
   function Consume_Quantized is new
     Internal.Encoder_Storage.Quantization_Operations
       .Consume_Truecolor_Pixels (Add_Quantized);
begin
   if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
      return Invalid_Transition (Object);
   elsif Source.Width /= Info.Width or else Source.Height /= Info.Height then
      return Reject_Frame_Request
        (Object, Errors.Make
           (Errors.Invalid_Dimensions,
            (Expected => Total,
             Actual => Geometry_Arithmetic.Area (Source.Width, Source.Height),
             others => <>)));
   end if;
   Outcome := Images.Validate (Source);
   if not Results.Succeeded (Outcome) then
      return Reject_Frame_Request (Object, Outcome.First_Error);
   end if;
   Outcome := Validate_Frame_Request (Object, Info);
   if not Results.Succeeded (Outcome) then
      return Reject_Frame_Request (Object, Outcome.First_Error);
   elsif Total > Object.Constraints.Max_Allocation_Bytes then
      return Reject_Frame_Request
        (Object, Errors.Make
           (Errors.Limit_Exceeded,
            (Expected => Object.Constraints.Max_Allocation_Bytes,
             Actual => Total, Limit => Allocation_Byte_Limit, others => <>)));
   elsif Total > Byte_Count (Natural'Last) then
      return Reject_Frame_Request
        (Object, Errors.Make
           (Errors.Integer_Overflow,
            (Expected => Byte_Count (Natural'Last), Actual => Total,
             others => <>)));
   end if;
   if Object.Options.Truecolor_Palettes = Use_Existing_Global then
      if not Object.Has_Global_Palette then
         return Reject_Frame_Request
           (Object, Errors.Make (Errors.Missing_Color_Table));
      end if;
      Quantize_Options.Palette :=
        (Strategy => Quantization.Use_Fixed_Palette,
         Fixed_Palette => Object.Global_Palette,
         Fixed_Transparent_Index => 0);
      Selection := Use_Global_Palette;
   end if;
   Outcome := Resource_Management.Ensure_Truecolor_Pixels (Object, Total);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Outcome := Internal.Encoder_Storage.Quantization_Operations.Quantize
     (Object.Resources, Source, Total, Quantized, Quantize_Options,
      Resource_Management.Quantization_Constraints (Object));
   if not Results.Succeeded (Outcome) then
      return Fail_Frame
        (Object, Resource_Management.Normalize_Quantization_Error
           (Object, Outcome.First_Error));
   end if;
   Adjusted.Control :=
     (if Quantized.Transparency.Present
      then (Has_Transparency => True,
            Disposal => Info.Control.Disposal,
            User_Input => Info.Control.User_Input,
            Delay_CS => Info.Control.Delay_CS,
            Transparent_Index => Quantized.Transparency.Index)
      else (Has_Transparency => False,
            Disposal => Info.Control.Disposal,
            User_Input => Info.Control.User_Input,
            Delay_CS => Info.Control.Delay_CS));
   if Object.Options.Truecolor_Palettes = Reuse_Identical_Global
     and then Object.Has_Global_Palette
     and then Palettes.Same_Entries (Quantized.Palette, Object.Global_Palette)
   then
      Selection := Use_Global_Palette;
   end if;
   return Consume_Quantized (Object.Resources, Total);
end Add_Truecolor_Frame;
