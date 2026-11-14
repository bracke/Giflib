with Giflib.Encoding.Resource_Management;
with Giflib.Encoding.Session_Transitions;
with Giflib.Encoding.State_Arithmetic;
with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Frame_Sources;
with Giflib.Encoding.Request_Validation;
with Giflib.Encoding.Wire_Output;
with Giflib.Internal.Container_Writer;
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

   function Validate_Preparation
     (Object : Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : out Preparation) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Data := (others => <>);
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      end if;
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
      return Results.Success;
   end Validate_Preparation;

   function Commit_Prefix
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : in out Preparation) return Results.Result
   is
      Outcome : Results.Result;
      Palette_Length : Natural;
   begin
      Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Outcome := Write_Header (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      if Info.Control /= Frames.Default_Control then
         Outcome := Wire_Output.Write
           (Object, Internal.Container_Writer.Graphic_Control (Info.Control));
         if not Results.Succeeded (Outcome) then
            return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
         end if;
         Session_Transitions.Record_Extension (Object);
      end if;
      Palette_Length := Natural
        (Encoding_Arithmetic.Encoded_Palette_Length
           (Encoding_Arithmetic.Palette_Length (Data.Effective.Length)));
      Outcome := Wire_Output.Write
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
         Outcome := Wire_Output.Write_Color_Table (Object, Data.Effective);
      end if;
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Data.Minimum := Byte
        (Encoding_Arithmetic.Minimum_LZW_Code_Size
           (Encoding_Arithmetic.Palette_Length (Palette_Length)));
      Outcome := Wire_Output.Write (Object, [1 => Data.Minimum]);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error));
   end Commit_Prefix;

   function Complete
     (Object : in out Encoder;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) return Results.Result is
   begin
      if not Results.Succeeded (Outcome) then
         Session_Transitions.Record_Output (Object, Compressed, Wire_Bytes);
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Session_Transitions.Complete_Frame (Object, Compressed, Wire_Bytes);
      return Results.Success;
   end Complete;

   generic
      type Source_Type (<>) is private;
      with function Source_Length (Source : Source_Type) return Byte_Count;
      with function Encode_Source
        (Object : in out Encoder;
         Info : Frame_Info;
         Source : Source_Type;
         Minimum : Byte;
         Maximum_Index : Byte;
         Compressed : out Byte_Count;
         Wire_Bytes : out Byte_Count) return Results.Result;
   function Add_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Source : Source_Type) return Results.Result;

   function Add_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Source : Source_Type) return Results.Result
   is
      Required : constant Byte_Count :=
        Geometry_Arithmetic.Area (Info.Width, Info.Height);
      Pixel_Count : constant Byte_Count := Source_Length (Source);
      Data : Preparation;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count;
   begin
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      elsif Pixel_Count /= Required then
         return Failure_Handling.Reject_Frame
           (Object, Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required, Actual => Pixel_Count, others => <>)));
      end if;
      Outcome := Validate_Preparation (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Commit_Prefix (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Encode_Source
        (Object, Info, Source, Data.Minimum,
         Byte (Data.Effective.Length - 1), Compressed, Wire_Bytes);
      return Complete (Object, Outcome, Compressed, Wire_Bytes);
   end Add_Frame;

   function Add_Indexed_Source is new Add_Frame
     (Source_Type => Streams.Byte_Array,
      Source_Length => Frame_Sources.Indexed_Length,
      Encode_Source => Frame_Sources.Encode_Indexed);

   function Add_Stored_Source is new Add_Frame
     (Source_Type => Byte_Count,
      Source_Length => Frame_Sources.Stored_Length,
      Encode_Source => Frame_Sources.Encode_Stored);

   function Add_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is
   begin
      return Add_Indexed_Source (Object, Info, Palette, Pixels);
   end Add_Indexed;

   function Add_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixel_Count : Byte_Count) return Results.Result
   is
   begin
      return Add_Stored_Source (Object, Info, Palette, Pixel_Count);
   end Add_Stored;
end Giflib.Encoding.Frame_Pipeline;
