with Giflib.Internal.Encoder_Storage.Frame_Operations;

separate (Giflib.Encoding)
function Add_Indexed_Frame
  (Object : in out Encoder;
   Info : Frame_Info;
   Palette : Frame_Palette;
   Pixels : Streams.Byte_Array) return Results.Result
is
   Effective : Palettes.Palette;
   Palette_Length : Natural;
   Outcome : Results.Result;
   Required_Pixels : constant Byte_Count :=
     Geometry_Arithmetic.Area (Info.Width, Info.Height);
   Remaining_Output : Byte_Count;
   Compressed : Byte_Count;
   Wire_Bytes : Byte_Count;
   Minimum : Byte;
begin
   if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
      return Invalid_Transition (Object);
   end if;
   Outcome := Validate_Frame_Request (Object, Info);
   if not Results.Succeeded (Outcome) then
      return Reject_Frame_Request (Object, Outcome.First_Error);
   elsif Byte_Count (Pixels'Length) /= Required_Pixels then
      return Reject_Frame_Request
        (Object, Errors.Make
           (Errors.Buffer_Size_Mismatch,
            (Expected => Required_Pixels,
             Actual => Byte_Count (Pixels'Length), others => <>)));
   end if;
   if Palette.Selection = Use_Local_Palette then
      Effective := Palette.Value;
   elsif Object.Has_Global_Palette then
      Effective := Object.Global_Palette;
   else
      return Reject_Frame_Request
        (Object, Errors.Make (Errors.Missing_Color_Table));
   end if;
   if Effective.Length < 2 then
      return Reject_Frame_Request
        (Object, Errors.Make (Errors.Missing_Color_Table));
   elsif Info.Control.Has_Transparency
     and then not Palettes.Contains (Effective, Info.Control.Transparent_Index)
   then
      return Reject_Frame_Request
        (Object, Errors.Make (Errors.Palette_Index_Out_Of_Range));
   end if;
   Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Outcome := Write_Header (Object);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   if Info.Control /= Frames.Default_Control then
      Outcome := Write_Raw
        (Object, Internal.Container_Writer.Graphic_Control (Info.Control));
      if not Results.Succeeded (Outcome) then
         return Fail_Frame (Object, Outcome.First_Error);
      end if;
      State_Arithmetic.Record_Extension (Object);
   end if;
   Palette_Length := Natural
     (Encoding_Arithmetic.Encoded_Palette_Length
        (Encoding_Arithmetic.Palette_Length (Effective.Length)));
   Outcome := Write_Raw
     (Object,
      Internal.Container_Writer.Image_Descriptor
        (Left => Info.Left,
         Top => Info.Top,
         Width => Info.Width,
         Height => Info.Height,
         Local_Palette =>
           (if Palette.Selection = Use_Local_Palette
            then (Present => True,
                  Length => Internal.Container_Writer.Palette_Length
                    (Effective.Length),
                  Sorted => False)
            else Internal.Container_Writer.No_Palette),
         Interlaced => Info.Interlaced));
   if Results.Succeeded (Outcome)
     and then Palette.Selection = Use_Local_Palette
   then
      Outcome := Write_Palette (Object, Effective);
   end if;
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Minimum := Byte
     (Encoding_Arithmetic.Minimum_LZW_Code_Size
        (Encoding_Arithmetic.Palette_Length (Palette_Length)));
   Outcome := Write_Raw (Object, [1 => Minimum]);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Remaining_Output := Object.Constraints.Max_Output_Bytes - Object.Bytes_Written;
   Outcome := Internal.Encoder_Storage.Frame_Operations.Encode_LZW
     (Object.Resources,
      Object.Output.all, Pixels, Minimum,
      Object.Constraints.Max_LZW_Work,
      Object.Constraints.Max_Compressed_Bytes - Object.Compressed_Bytes_Written,
      Remaining_Output, Compressed, Wire_Bytes,
      Maximum_Index => Byte (Effective.Length - 1),
      Interlace_Width => (if Info.Interlaced then Natural (Info.Width) else 0),
      Interlace_Height => (if Info.Interlaced then Natural (Info.Height) else 0));
   Object.Bytes_Written := Object.Bytes_Written + Wire_Bytes;
   Object.Compressed_Bytes_Written := Object.Compressed_Bytes_Written + Compressed;
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   State_Arithmetic.Frame_Accepted (Object);
   return Results.Success;
end Add_Indexed_Frame;
