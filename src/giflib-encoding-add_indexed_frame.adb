separate (Giflib.Encoding)
function Add_Indexed_Frame
  (Object : in out Encoder;
   Info : Frame_Info;
   Selection : Palette_Selection;
   Local_Palette : Palettes.Palette;
   Pixels : Streams.Byte_Array) return Results.Result
is
   Effective : Palettes.Palette;
   Palette_Length : Natural;
   Size_Code : Descriptor_Arithmetic.Palette_Size_Code := 0;
   Descriptor : Streams.Byte_Array (1 .. 10);
   GCE : Streams.Byte_Array (1 .. 8);
   Outcome : Results.Result;
   Required_Pixels : constant Byte_Count :=
     Geometry_Arithmetic.Area (Info.Width, Info.Height);
   Remaining_Output : Byte_Count;
   Compressed : Byte_Count;
   Minimum : Byte;
begin
   if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
      return Invalid_Transition (Object);
   end if;
   Outcome := Validate_Frame_Request (Object, Info);
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   elsif Byte_Count (Pixels'Length) /= Required_Pixels then
      return Fail_Frame
        (Object, Errors.Make
           (Errors.LZW_Output_Size_Mismatch,
            (Expected => Required_Pixels,
             Actual => Byte_Count (Pixels'Length), others => <>)));
   end if;
   if Selection = Use_Local_Palette then
      Effective := Local_Palette;
   elsif Object.Has_Global_Palette then
      Effective := Object.Global_Palette;
   else
      return Fail_Frame (Object, Errors.Make (Errors.Missing_Color_Table));
   end if;
   if Effective.Length < 2 then
      return Fail_Frame (Object, Errors.Make (Errors.Missing_Color_Table));
   elsif Info.Control.Has_Transparency
     and then not Palettes.Contains (Effective, Info.Control.Transparent_Index)
   then
      return Fail_Frame
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
      GCE :=
        [16#21#, 16#F9#, 4,
         Internal.Extension_Arithmetic.Encode_Graphic_Control (Info.Control),
         Internal.Extension_Arithmetic.Low_Byte (Natural (Info.Control.Delay_CS)),
         Internal.Extension_Arithmetic.High_Byte (Natural (Info.Control.Delay_CS)),
         Byte (Info.Control.Transparent_Index), 0];
      Outcome := Write_Raw (Object, GCE);
      if not Results.Succeeded (Outcome) then
         return Fail_Frame (Object, Outcome.First_Error);
      end if;
      Object.Extensions_Written := Object.Extensions_Written + 1;
   end if;
   Palette_Length := Natural
     (Encoding_Arithmetic.Encoded_Palette_Length
        (Encoding_Arithmetic.Palette_Length (Effective.Length)));
   if Selection = Use_Local_Palette then
      Size_Code := Descriptor_Arithmetic.Palette_Size_Code
        (Encoding_Arithmetic.Size_Code
           (Encoding_Arithmetic.Palette_Length (Palette_Length)));
   end if;
   Descriptor :=
     [16#2C#,
      Internal.Extension_Arithmetic.Low_Byte (Natural (Info.Left)),
      Internal.Extension_Arithmetic.High_Byte (Natural (Info.Left)),
      Internal.Extension_Arithmetic.Low_Byte (Natural (Info.Top)),
      Internal.Extension_Arithmetic.High_Byte (Natural (Info.Top)),
      Internal.Extension_Arithmetic.Low_Byte (Natural (Info.Width)),
      Internal.Extension_Arithmetic.High_Byte (Natural (Info.Width)),
      Internal.Extension_Arithmetic.Low_Byte (Natural (Info.Height)),
      Internal.Extension_Arithmetic.High_Byte (Natural (Info.Height)),
      Descriptor_Arithmetic.Encode_Image
        (Selection = Use_Local_Palette, Info.Interlaced, False, Size_Code)];
   Outcome := Write_Raw (Object, Descriptor);
   if Results.Succeeded (Outcome) and then Selection = Use_Local_Palette then
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
   Outcome := Internal.LZW_Encoding.Encode
     (Object.Resources.LZW_Workspace, Object.Output.all, Pixels, Minimum,
      Object.Constraints.Max_LZW_Work,
      Object.Constraints.Max_Compressed_Bytes - Object.Compressed_Bytes_Written,
      Remaining_Output, Compressed,
      Maximum_Index => Byte (Effective.Length - 1),
      Interlace_Width => (if Info.Interlaced then Natural (Info.Width) else 0),
      Interlace_Height => (if Info.Interlaced then Natural (Info.Height) else 0));
   declare
      Current : constant Streams.Destination_Position_Result :=
        Output_Position (Object);
   begin
      if not Current.Available or else Current.Value < Object.Start_Offset then
         return Fail_Frame
           (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Object.Bytes_Written := Byte_Count (Current.Value - Object.Start_Offset);
   end;
   if not Results.Succeeded (Outcome) then
      return Fail_Frame (Object, Outcome.First_Error);
   end if;
   Object.Compressed_Bytes_Written := Object.Compressed_Bytes_Written + Compressed;
   Object.Frames_Written := Object.Frames_Written + 1;
   Object.Current_State := Accepting_Frames;
   return Results.Success;
end Add_Indexed_Frame;
