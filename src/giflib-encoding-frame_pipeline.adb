with Giflib.Encoding.Resource_Management;
with Giflib.Encoding.Session_Transitions;
with Giflib.Encoding.State_Arithmetic;
with Giflib.Internal.Container_Writer;
with Giflib.Internal.Encoder_Storage.Frame_Operations;
with Giflib.Internal.Encoding_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Encoding.Frame_Pipeline is
   use type Frames.Graphic_Control;
   package Encoding_Arithmetic renames Internal.Encoding_Arithmetic;
   package Geometry_Arithmetic renames Internal.Geometry_Arithmetic;

   type Preparation is record
      Effective : Palettes.Palette;
      Minimum : Byte := 2;
   end record;

   function Prepare
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : out Preparation) return Results.Result
   is
      Outcome : Results.Result;
      Palette_Length : Natural;
   begin
      Data := (others => <>);
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Invalid_Transition (Object);
      end if;
      Outcome := Validate_Frame_Request (Object, Info);
      if not Results.Succeeded (Outcome) then
         return Reject_Frame_Request (Object, Outcome.First_Error);
      end if;
      if Palette.Selection = Use_Local_Palette then
         Data.Effective := Palette.Value;
      elsif Object.Has_Global_Palette then
         Data.Effective := Object.Global_Palette;
      else
         return Reject_Frame_Request
           (Object, Errors.Make (Errors.Missing_Color_Table));
      end if;
      if Data.Effective.Length < 2 then
         return Reject_Frame_Request
           (Object, Errors.Make (Errors.Missing_Color_Table));
      elsif Info.Control.Has_Transparency
        and then not Palettes.Contains
          (Data.Effective, Info.Control.Transparent_Index)
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
         Session_Transitions.Record_Extension (Object);
      end if;
      Palette_Length := Natural
        (Encoding_Arithmetic.Encoded_Palette_Length
           (Encoding_Arithmetic.Palette_Length (Data.Effective.Length)));
      Outcome := Write_Raw
        (Object,
         Internal.Container_Writer.Image_Descriptor
           (Left => Info.Left, Top => Info.Top,
            Width => Info.Width, Height => Info.Height,
            Local_Palette =>
              (if Palette.Selection = Use_Local_Palette
               then (Present => True,
                     Length => Internal.Container_Writer.Palette_Length
                       (Data.Effective.Length),
                     Sorted => False)
               else Internal.Container_Writer.No_Palette),
            Interlaced => Info.Interlaced));
      if Results.Succeeded (Outcome)
        and then Palette.Selection = Use_Local_Palette
      then
         Outcome := Write_Palette (Object, Data.Effective);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail_Frame (Object, Outcome.First_Error);
      end if;
      Data.Minimum := Byte
        (Encoding_Arithmetic.Minimum_LZW_Code_Size
           (Encoding_Arithmetic.Palette_Length (Palette_Length)));
      Outcome := Write_Raw (Object, [1 => Data.Minimum]);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Fail_Frame (Object, Outcome.First_Error));
   end Prepare;

   function Complete
     (Object : in out Encoder;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) return Results.Result is
   begin
      if not Results.Succeeded (Outcome) then
         Session_Transitions.Record_Output (Object, Compressed, Wire_Bytes);
         return Fail_Frame (Object, Outcome.First_Error);
      end if;
      Session_Transitions.Complete_Frame (Object, Compressed, Wire_Bytes);
      return Results.Success;
   end Complete;

   function Add_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is
      Required : constant Byte_Count :=
        Geometry_Arithmetic.Area (Info.Width, Info.Height);
      Data : Preparation;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count;
   begin
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Invalid_Transition (Object);
      end if;
      if Byte_Count (Pixels'Length) /= Required then
         return Reject_Frame_Request
           (Object, Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required, Actual => Byte_Count (Pixels'Length),
                others => <>)));
      end if;
      Outcome := Prepare (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Internal.Encoder_Storage.Frame_Operations.Encode_LZW
        (Object.Resources, Object.Output.all, Pixels, Data.Minimum,
         Object.Constraints.Max_LZW_Work,
         Object.Constraints.Max_Compressed_Bytes
           - Object.Compressed_Bytes_Written,
         Object.Constraints.Max_Output_Bytes - Object.Bytes_Written,
         Compressed, Wire_Bytes,
         Maximum_Index => Byte (Data.Effective.Length - 1),
         Interlace_Width =>
           (if Info.Interlaced then Natural (Info.Width) else 0),
         Interlace_Height =>
           (if Info.Interlaced then Natural (Info.Height) else 0));
      return Complete (Object, Outcome, Compressed, Wire_Bytes);
   end Add_Indexed;

   function Add_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixel_Count : Byte_Count) return Results.Result
   is
      Required : constant Byte_Count :=
        Geometry_Arithmetic.Area (Info.Width, Info.Height);
      Data : Preparation;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count;
   begin
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Invalid_Transition (Object);
      end if;
      if Pixel_Count /= Required then
         return Reject_Frame_Request
           (Object, Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required, Actual => Pixel_Count, others => <>)));
      end if;
      Outcome := Prepare (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Internal.Encoder_Storage.Frame_Operations.Encode_Stored_LZW
        (Object.Resources, Object.Output.all, Pixel_Count, Data.Minimum,
         Object.Constraints.Max_LZW_Work,
         Object.Constraints.Max_Compressed_Bytes
           - Object.Compressed_Bytes_Written,
         Object.Constraints.Max_Output_Bytes - Object.Bytes_Written,
         Compressed, Wire_Bytes,
         Maximum_Index => Byte (Data.Effective.Length - 1),
         Interlace_Width =>
           (if Info.Interlaced then Natural (Info.Width) else 0),
         Interlace_Height =>
           (if Info.Interlaced then Natural (Info.Height) else 0));
      return Complete (Object, Outcome, Compressed, Wire_Bytes);
   end Add_Stored;
end Giflib.Encoding.Frame_Pipeline;
