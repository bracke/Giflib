separate (Giflib.Encoding)
function Add_Truecolor_Frame
  (Object : in out Encoder;
   Info : Frame_Info;
   Source : Images.Image_View;
   Options : Quantization.Quantize_Options := Quantization.Default_Options)
   return Results.Result
is
   Total : constant Byte_Count := Geometry_Arithmetic.Area (Info.Width, Info.Height);
   Palette : Palettes.Palette;
   Has_Transparency : Boolean;
   Transparent_Index : Palette_Index;
   Quantize_Options : Quantization.Quantize_Options := Options;
   Adjusted : Frame_Info := Info;
   Selection : Palette_Selection := Use_Local_Palette;
   Outcome : Results.Result;
begin
   if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
      return Invalid_Transition (Object);
   elsif Source.Width /= Info.Width or else Source.Height /= Info.Height then
      return Fail_Frame
        (Object, Errors.Make
           (Errors.Invalid_Dimensions,
            (Expected => Total,
             Actual => Geometry_Arithmetic.Area (Source.Width, Source.Height),
             others => <>)));
   end if;
   Outcome := Images.Validate (Source);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Outcome := Validate_Frame_Request (Object, Info);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   elsif Total > Object.Constraints.Max_Allocation_Bytes then
      return Fail_Frame
        (Object, Errors.Make
           (Errors.Limit_Exceeded,
            (Expected => Object.Constraints.Max_Allocation_Bytes,
             Actual => Total, Limit => Allocation_Byte_Limit, others => <>)));
   elsif Total > Byte_Count (Natural'Last) then
      return Fail_Frame
        (Object, Errors.Make
           (Errors.Integer_Overflow,
            (Expected => Byte_Count (Natural'Last), Actual => Total,
             others => <>)));
   end if;
   if Object.Options.Truecolor_Palettes = Use_Existing_Global then
      if not Object.Has_Global_Palette then
         return Fail_Frame
           (Object, Errors.Make (Errors.Missing_Color_Table));
      end if;
      Quantize_Options.Strategy := Quantization.Use_Fixed_Palette;
      Quantize_Options.Fixed_Palette := Object.Global_Palette;
      Selection := Use_Global_Palette;
   end if;
   Outcome := Resource_Management.Ensure_Truecolor_Pixels (Object, Total);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Outcome := Quantization.Quantize
     (Object.Resources.Quantizer, Source,
      Buffers.Value (Object.Resources.Truecolor_Pixels).all (1 .. Natural (Total)),
      Palette, Has_Transparency, Transparent_Index, Quantize_Options,
      Resource_Management.Quantization_Constraints (Object));
   if not Results.Succeeded (Outcome) then
      return Fail_Frame
        (Object, Resource_Management.Normalize_Quantization_Error
           (Object, Outcome.First_Error));
   end if;
   if Has_Transparency then
      Adjusted.Control.Has_Transparency := True;
      Adjusted.Control.Transparent_Index := Transparent_Index;
   else
      Adjusted.Control.Has_Transparency := False;
      Adjusted.Control.Transparent_Index := 0;
   end if;
   if Object.Options.Truecolor_Palettes = Reuse_Identical_Global
     and then Object.Has_Global_Palette
     and then Palettes.Same_Entries (Palette, Object.Global_Palette)
   then
      Selection := Use_Global_Palette;
   end if;
   return Add_Indexed_Frame
     (Object, Adjusted, Selection, Palette,
      Buffers.Value (Object.Resources.Truecolor_Pixels).all (1 .. Natural (Total)));
end Add_Truecolor_Frame;
