with Ada.Unchecked_Deallocation;

with Giflib.Internal.LZW_Encoding;

package body Giflib.Encoding is
   use type Errors.Error_Code;
   use type Frames.Graphic_Control;

   function Invalid_Transition (Object : Encoder) return Results.Result is
   begin
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            (Destination => (if Object.Output = null then 0 else Object.Output.Offset), others => <>)));
   end Invalid_Transition;

   function Fail (Object : in out Encoder; Item : Errors.Error) return Results.Result is
   begin
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Item;
      end if;
      Object.Current_State := Failed;
      return Results.Failure (Object.Diagnostic);
   end Fail;

   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      if Object.Bytes_Written > Object.Constraints.Max_Output_Bytes
        or else Byte_Count (Data'Length) > Object.Constraints.Max_Output_Bytes - Object.Bytes_Written
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Destination => Object.Output.Offset,
                Expected => Object.Constraints.Max_Output_Bytes,
                Actual => Object.Bytes_Written + Byte_Count (Data'Length),
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      Outcome := Streams.Write_All (Object.Output.all, Data);
      if Results.Succeeded (Outcome) then
         Object.Bytes_Written := Object.Bytes_Written + Byte_Count (Data'Length);
      end if;
      return Outcome;
   end Write_Raw;

   function Encoded_Palette_Length (Length : Natural) return Natural is
      Result : Natural := 2;
   begin
      while Result < Length loop
         Result := Result * 2;
      end loop;
      return Result;
   end Encoded_Palette_Length;

   function Size_Code (Length : Natural) return Natural is
      Value : Natural := Length;
      Result : Natural := 0;
   begin
      while Value > 2 loop
         Value := Value / 2;
         Result := Result + 1;
      end loop;
      return Result;
   end Size_Code;

   function Minimum_Code_Size (Length : Natural) return Byte is
      Value : Natural := 2;
      Bits : Natural := 1;
   begin
      while Value < Length loop
         Value := Value * 2;
         Bits := Bits + 1;
      end loop;
      return Byte (Natural'Max (2, Bits));
   end Minimum_Code_Size;

   function Write_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result
   is
      Length : constant Natural := Encoded_Palette_Length (Palette.Length);
      Data : Streams.Byte_Array (1 .. Length * 3) := [others => 0];
   begin
      for I in 0 .. Palette.Length - 1 loop
         Data (I * 3 + 1) := Palette.Colors (Palette_Index (I)).Red;
         Data (I * 3 + 2) := Palette.Colors (Palette_Index (I)).Green;
         Data (I * 3 + 3) := Palette.Colors (Palette_Index (I)).Blue;
      end loop;
      return Write_Raw (Object, Data);
   end Write_Palette;

   function Write_Header (Object : in out Encoder) return Results.Result is
      Signature : Streams.Byte_Array (1 .. 6);
      Descriptor : Streams.Byte_Array (1 .. 7);
      Packed : Natural := (Object.Screen.Color_Resolution - 1) * 16;
      Outcome : Results.Result;
      Palette_Length : Natural := 0;
   begin
      if Object.Header_Written then
         return Results.Success;
      end if;
      if Object.Options.Version = Force_GIF87a and then Object.Has_Loop then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      end if;
      Signature :=
        (if Object.Options.Version = Force_GIF87a
         then [71, 73, 70, 56, 55, 97]
         else [71, 73, 70, 56, 57, 97]);
      if Object.Has_Global_Palette then
         Palette_Length := Encoded_Palette_Length (Object.Global_Palette.Length);
         Packed := Packed + 16#80# + Size_Code (Palette_Length);
      end if;
      Descriptor :=
        [Byte (Natural (Object.Screen.Width) mod 256),
         Byte (Natural (Object.Screen.Width) / 256),
         Byte (Natural (Object.Screen.Height) mod 256),
         Byte (Natural (Object.Screen.Height) / 256),
         Byte (Packed),
         Byte (Object.Screen.Background_Index),
         Object.Screen.Pixel_Aspect_Ratio];
      Outcome := Write_Raw (Object, Signature);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, Descriptor);
      end if;
      if Results.Succeeded (Outcome) and then Object.Has_Global_Palette then
         Outcome := Write_Palette (Object, Object.Global_Palette);
      end if;
      if Results.Succeeded (Outcome) and then Object.Has_Loop then
         declare
            Loop_Block : constant Streams.Byte_Array :=
              [16#21#, 16#FF#, 11,
               78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
               3, 1, Byte (Object.Loop_Count mod 256), Byte (Object.Loop_Count / 256), 0];
         begin
            Outcome := Write_Raw (Object, Loop_Block);
         end;
      end if;
      if Results.Succeeded (Outcome) then
         Object.Header_Written := True;
      end if;
      return Outcome;
   end Write_Header;

   function Initialize
     (Object : in out Encoder;
      Output : not null Destination_Access;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      if Object.Current_State not in Uninitialized | Finalized then
         return Invalid_Transition (Object);
      end if;
      Object.Output := Output;
      Object.Options := Options;
      Object.Constraints := Constraints;
      Object.Screen := (others => <>);
      Object.Global_Palette := (others => <>);
      Object.Has_Global_Palette := False;
      Object.Has_Loop := False;
      Object.Loop_Count := 0;
      Object.Header_Written := False;
      Object.Frames_Written := 0;
      Object.Extensions_Written := 0;
      Object.Start_Offset := Output.Offset;
      Object.Bytes_Written := 0;
      Object.Compressed_Bytes_Written := 0;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      Object.Current_State := Initialized;
      return Results.Success;
   end Initialize;

   function Define_Screen (Object : in out Encoder; Screen : Screen_Info) return Results.Result is
      Pixels : constant Byte_Count := Byte_Count (Screen.Width) * Byte_Count (Screen.Height);
   begin
      if Object.Current_State /= Initialized then
         return Invalid_Transition (Object);
      elsif Screen.Width > Object.Constraints.Max_Logical_Width then
         return Fail
           (Object, Errors.Make (Errors.Limit_Exceeded,
                                 (Expected => Byte_Count (Object.Constraints.Max_Logical_Width),
                                  Actual => Byte_Count (Screen.Width),
                                  Limit => Logical_Width_Limit, others => <>)));
      elsif Screen.Height > Object.Constraints.Max_Logical_Height then
         return Fail
           (Object, Errors.Make (Errors.Limit_Exceeded,
                                 (Expected => Byte_Count (Object.Constraints.Max_Logical_Height),
                                  Actual => Byte_Count (Screen.Height),
                                  Limit => Logical_Height_Limit, others => <>)));
      elsif Pixels > Byte_Count (Object.Constraints.Max_Canvas_Pixels) then
         return Fail
           (Object, Errors.Make (Errors.Limit_Exceeded,
                                 (Expected => Byte_Count (Object.Constraints.Max_Canvas_Pixels),
                                  Actual => Pixels, Limit => Canvas_Pixel_Limit, others => <>)));
      end if;
      Object.Screen := Screen;
      Object.Current_State := Screen_Defined;
      return Results.Success;
   end Define_Screen;

   function Set_Global_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result
   is
   begin
      if Object.Current_State /= Screen_Defined or else Object.Header_Written then
         return Invalid_Transition (Object);
      elsif Palette.Length < 2 then
         return Fail (Object, Errors.Make (Errors.Missing_Color_Table));
      elsif not Palettes.Contains (Palette, Object.Screen.Background_Index) then
         return Fail (Object, Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      Object.Global_Palette := Palette;
      Object.Has_Global_Palette := True;
      return Results.Success;
   end Set_Global_Palette;

   function Set_Loop_Count
     (Object : in out Encoder;
      Count : Natural) return Results.Result
   is
   begin
      if Object.Current_State /= Screen_Defined or else Object.Header_Written then
         return Invalid_Transition (Object);
      elsif Count > 65_535 then
         return Fail (Object, Errors.Make (Errors.Integer_Overflow));
      elsif Object.Options.Version = Force_GIF87a then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      Object.Has_Loop := True;
      Object.Loop_Count := Count;
      return Results.Success;
   end Set_Loop_Count;

   function Add_Indexed_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Selection : Palette_Selection;
      Local_Palette : Palettes.Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is
      Effective : Palettes.Palette;
      Palette_Length : Natural;
      Packed : Natural := (if Info.Interlaced then 16#40# else 0);
      Descriptor : Streams.Byte_Array (1 .. 10);
      GCE : Streams.Byte_Array (1 .. 8);
      Outcome : Results.Result;
      Required_Pixels : constant Byte_Count := Byte_Count (Info.Width) * Byte_Count (Info.Height);
      Remaining_Output : Byte_Count;
      Compressed : Byte_Count;
      Minimum : Byte;
      Control_Packed : Natural;
   begin
      if Object.Current_State not in Screen_Defined | Accepting_Frames then
         return Invalid_Transition (Object);
      elsif Object.Frames_Written >= Object.Constraints.Max_Frames then
         return Fail (Object, Errors.Make (Errors.Limit_Exceeded,
                                           (Limit => Frame_Count_Limit, others => <>)));
      elsif Byte_Count (Pixels'Length) /= Required_Pixels then
         return Fail (Object, Errors.Make (Errors.LZW_Output_Size_Mismatch,
                                           (Expected => Required_Pixels,
                                            Actual => Byte_Count (Pixels'Length), others => <>)));
      elsif Byte_Count (Info.Left) + Byte_Count (Info.Width) > Byte_Count (Object.Screen.Width)
        or else Byte_Count (Info.Top) + Byte_Count (Info.Height) > Byte_Count (Object.Screen.Height)
      then
         return Fail (Object, Errors.Make (Errors.Frame_Out_Of_Bounds));
      end if;
      if Selection = Use_Local_Palette then
         Effective := Local_Palette;
      elsif Object.Has_Global_Palette then
         Effective := Object.Global_Palette;
      else
         return Fail (Object, Errors.Make (Errors.Missing_Color_Table));
      end if;
      if Effective.Length < 2 then
         return Fail (Object, Errors.Make (Errors.Missing_Color_Table));
      elsif Info.Control.Has_Transparency
        and then not Palettes.Contains (Effective, Info.Control.Transparent_Index)
      then
         return Fail (Object, Errors.Make (Errors.Palette_Index_Out_Of_Range));
      end if;
      for Value of Pixels loop
         if not Palettes.Contains (Effective, Palette_Index (Value)) then
            return Fail (Object, Errors.Make (Errors.Palette_Index_Out_Of_Range));
         end if;
      end loop;
      if Object.Options.Version = Force_GIF87a and then Info.Control /= Frames.Default_Control then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      Outcome := Write_Header (Object);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      if Info.Control /= Frames.Default_Control then
         Control_Packed := Natural (Info.Control.Disposal) * 4
           + (if Info.Control.User_Input then 2 else 0)
           + (if Info.Control.Has_Transparency then 1 else 0);
         GCE :=
           [16#21#, 16#F9#, 4, Byte (Control_Packed),
            Byte (Natural (Info.Control.Delay_CS) mod 256),
            Byte (Natural (Info.Control.Delay_CS) / 256),
            Byte (Info.Control.Transparent_Index), 0];
         Outcome := Write_Raw (Object, GCE);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Palette_Length := Encoded_Palette_Length (Effective.Length);
      if Selection = Use_Local_Palette then
         Packed := Packed + 16#80# + Size_Code (Palette_Length);
      end if;
      Descriptor :=
        [16#2C#,
         Byte (Natural (Info.Left) mod 256), Byte (Natural (Info.Left) / 256),
         Byte (Natural (Info.Top) mod 256), Byte (Natural (Info.Top) / 256),
         Byte (Natural (Info.Width) mod 256), Byte (Natural (Info.Width) / 256),
         Byte (Natural (Info.Height) mod 256), Byte (Natural (Info.Height) / 256),
         Byte (Packed)];
      Outcome := Write_Raw (Object, Descriptor);
      if Results.Succeeded (Outcome) and then Selection = Use_Local_Palette then
         Outcome := Write_Palette (Object, Effective);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Minimum := Minimum_Code_Size (Palette_Length);
      Outcome := Write_Raw (Object, [1 => Minimum]);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Remaining_Output := Object.Constraints.Max_Output_Bytes - Object.Bytes_Written;
      Outcome := Internal.LZW_Encoding.Encode
        (Object.Output.all,
         Pixels,
         Minimum,
         Object.Constraints.Max_LZW_Work,
         Object.Constraints.Max_Compressed_Bytes - Object.Compressed_Bytes_Written,
         Remaining_Output,
         Compressed,
         Interlace_Width => (if Info.Interlaced then Natural (Info.Width) else 0),
         Interlace_Height => (if Info.Interlaced then Natural (Info.Height) else 0));
      Object.Bytes_Written := Byte_Count (Object.Output.Offset - Object.Start_Offset);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Object.Compressed_Bytes_Written := Object.Compressed_Bytes_Written + Compressed;
      Object.Frames_Written := Object.Frames_Written + 1;
      Object.Current_State := Accepting_Frames;
      return Results.Success;
   end Add_Indexed_Frame;

   function Write_Extension_Prefix
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Position : out Natural) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Position := 0;
      Outcome := Write_Raw (Object, [16#21#, Info.Label]);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Fixed_Length > 0 then
         if Payload'Length < Fixed_Length then
            return Results.Failure (Errors.Make (Errors.Invalid_Extension));
         end if;
         Outcome := Write_Raw (Object, [1 => Byte (Fixed_Length)]);
         if Results.Succeeded (Outcome) then
            Outcome := Write_Raw
              (Object, Payload (Payload'First .. Payload'First + Fixed_Length - 1));
         end if;
         Position := Fixed_Length;
      end if;
      return Outcome;
   end Write_Extension_Prefix;

   function Validate_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Fixed_Length : out Natural) return Results.Result
   is
   begin
      Fixed_Length := 0;
      if Object.Current_State not in Screen_Defined | Accepting_Frames then
         return Invalid_Transition (Object);
      elsif Object.Options.Version = Force_GIF87a then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      elsif Object.Extensions_Written >= Object.Constraints.Max_Extensions then
         return Fail
           (Object, Errors.Make (Errors.Limit_Exceeded,
                                 (Limit => Extension_Count_Limit, others => <>)));
      elsif Byte_Count (Payload'Length) > Object.Constraints.Max_Per_Extension_Bytes then
         return Fail
           (Object, Errors.Make (Errors.Limit_Exceeded,
                                 (Expected => Object.Constraints.Max_Per_Extension_Bytes,
                                  Actual => Byte_Count (Payload'Length),
                                  Limit => Per_Extension_Byte_Limit, others => <>)));
      end if;
      case Info.Kind is
         when Metadata.Graphic_Control_Extension =>
            return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
         when Metadata.Application_Extension =>
            Fixed_Length := 11;
         when Metadata.Plain_Text_Extension =>
            Fixed_Length := 12;
         when Metadata.Comment_Extension | Metadata.Unknown_Extension =>
            Fixed_Length := 0;
      end case;
      if Payload'Length < Fixed_Length then
         return Fail (Object, Errors.Make (Errors.Invalid_Extension));
      end if;
      return Results.Success;
   end Validate_Extension;

   function Add_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result
   is
      Fixed_Length : Natural;
      Position : Natural;
      Chunk : Natural;
      Outcome : Results.Result;
   begin
      Outcome := Validate_Extension (Object, Info, Payload, Fixed_Length);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Extension_Prefix (Object, Info, Payload, Fixed_Length, Position);
      end if;
      while Results.Succeeded (Outcome) and then Position < Payload'Length loop
         Chunk := Natural'Min (255, Payload'Length - Position);
         Outcome := Write_Raw (Object, [1 => Byte (Chunk)]);
         if Results.Succeeded (Outcome) then
            Outcome := Write_Raw
              (Object, Payload (Payload'First + Position .. Payload'First + Position + Chunk - 1));
         end if;
         Position := Position + Chunk;
      end loop;
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, [1 => 0]);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Object.Extensions_Written := Object.Extensions_Written + 1;
      Object.Current_State := Accepting_Frames;
      return Results.Success;
   end Add_Extension;

   function Add_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
      Fixed_Length : Natural;
      Position : Natural;
      Sum : Byte_Count := 0;
      Outcome : Results.Result;
      First_Chunk : Boolean := True;
   begin
      Outcome := Validate_Extension (Object, Info, Payload, Fixed_Length);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      for Length of Chunk_Lengths loop
         Sum := Sum + Byte_Count (Length);
      end loop;
      if Sum /= Byte_Count (Payload'Length)
        or else (Fixed_Length > 0
                 and then (Chunk_Lengths'Length = 0
                           or else Chunk_Lengths (Chunk_Lengths'First) /= Fixed_Length))
      then
         return Fail (Object, Errors.Make (Errors.Invalid_Extension));
      end if;
      Outcome := Write_Header (Object);
      Position := 0;
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, [16#21#, Info.Label]);
      end if;
      for Length of Chunk_Lengths loop
         exit when not Results.Succeeded (Outcome);
         if First_Chunk and then Fixed_Length > 0 then
            Outcome := Write_Raw (Object, [1 => Byte (Fixed_Length)]);
         else
            Outcome := Write_Raw (Object, [1 => Byte (Length)]);
         end if;
         if Results.Succeeded (Outcome) then
            Outcome := Write_Raw
              (Object, Payload (Payload'First + Position .. Payload'First + Position + Length - 1));
         end if;
         Position := Position + Length;
         First_Chunk := False;
      end loop;
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, [1 => 0]);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Object.Extensions_Written := Object.Extensions_Written + 1;
      Object.Current_State := Accepting_Frames;
      return Results.Success;
   end Add_Extension_Exact;

   function Add_Truecolor_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Source : Images.Image_View;
      Options : Quantization.Quantize_Options := Quantization.Default_Options) return Results.Result
   is
      type Pixel_Access is access Streams.Byte_Array;
      procedure Free is new Ada.Unchecked_Deallocation (Streams.Byte_Array, Pixel_Access);
      Total : constant Byte_Count := Byte_Count (Info.Width) * Byte_Count (Info.Height);
      Pixels : Pixel_Access := null;
      Palette : Palettes.Palette;
      Has_Transparency : Boolean;
      Transparent_Index : Palette_Index;
      Quantize_Options : Quantization.Quantize_Options := Options;
      Adjusted : Frame_Info := Info;
      Selection : Palette_Selection := Use_Local_Palette;
      Outcome : Results.Result;
   begin
      if Object.Current_State not in Screen_Defined | Accepting_Frames then
         return Invalid_Transition (Object);
      elsif Source.Width /= Info.Width or else Source.Height /= Info.Height then
         return Fail
           (Object, Errors.Make
              (Errors.Invalid_Dimensions,
               (Expected => Total,
                Actual => Byte_Count (Source.Width) * Byte_Count (Source.Height), others => <>)));
      elsif Total > Object.Constraints.Max_Allocation_Bytes then
         return Fail
           (Object, Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Object.Constraints.Max_Allocation_Bytes, Actual => Total,
                Limit => Allocation_Byte_Limit, others => <>)));
      end if;
      if Object.Options.Truecolor_Palettes = Use_Existing_Global then
         if not Object.Has_Global_Palette then
            return Fail (Object, Errors.Make (Errors.Missing_Color_Table));
         end if;
         Quantize_Options.Strategy := Quantization.Use_Fixed_Palette;
         Quantize_Options.Fixed_Palette := Object.Global_Palette;
         Selection := Use_Global_Palette;
      end if;
      Pixels := new Streams.Byte_Array (1 .. Natural (Total));
      Outcome := Quantization.Quantize
        (Source, Pixels.all, Palette, Has_Transparency, Transparent_Index,
         Quantize_Options, Object.Constraints);
      if not Results.Succeeded (Outcome) then
         Free (Pixels);
         return Fail (Object, Outcome.First_Error);
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
      Outcome := Add_Indexed_Frame (Object, Adjusted, Selection, Palette, Pixels.all);
      Free (Pixels);
      return Outcome;
   exception
      when Storage_Error =>
         if Pixels /= null then
            Free (Pixels);
         end if;
         return Fail
           (Object, Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Object.Constraints.Max_Allocation_Bytes,
                Limit => Allocation_Byte_Limit, others => <>)));
   end Add_Truecolor_Frame;

   function Finish (Object : in out Encoder) return Results.Result is
      Outcome : Results.Result;
      Flush_Error : Errors.Error;
   begin
      if Object.Current_State = Completed then
         return Results.Success;
      elsif Object.Current_State not in Screen_Defined | Accepting_Frames then
         return Invalid_Transition (Object);
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, [1 => 16#3B#]);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Flush_Error := Object.Output.Flush;
      if Errors.Is_Fatal (Flush_Error) then
         return Fail (Object, Flush_Error);
      end if;
      Object.Current_State := Completed;
      return Results.Success;
   end Finish;

   function Cancel (Object : in out Encoder) return Results.Result is
   begin
      if Object.Current_State in Initialized | Screen_Defined | Accepting_Frames then
         Object.Current_State := Cancelled;
         Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
         return Results.Success;
      elsif Object.Current_State = Cancelled then
         return Results.Success;
      end if;
      return Invalid_Transition (Object);
   end Cancel;

   function State (Object : Encoder) return Encoder_State is
   begin
      return Object.Current_State;
   end State;

   function First_Error (Object : Encoder) return Errors.Error is
   begin
      return Object.Diagnostic;
   end First_Error;

   procedure Finalize (Object : in out Encoder) is
   begin
      Object.Output := null;
      Object.Current_State := Finalized;
   end Finalize;
end Giflib.Encoding;
