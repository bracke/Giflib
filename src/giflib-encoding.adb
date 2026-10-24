with Giflib.Encoding.Extensions;
with Giflib.Encoding.Resource_Management;
with Giflib.Internal.Descriptor_Arithmetic;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Encoding_Arithmetic;
with Giflib.Encoding.State_Arithmetic;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Session_Arithmetic;

package body Giflib.Encoding is
   use type Errors.Error_Code;
   use type Frames.Graphic_Control;
   package Descriptor_Arithmetic renames Internal.Descriptor_Arithmetic;
   package Buffers renames Internal.Owned_Buffers;
   package Encoding_Arithmetic renames Internal.Encoding_Arithmetic;
   package Geometry_Arithmetic renames Internal.Geometry_Arithmetic;
   package Session_Arithmetic renames Internal.Session_Arithmetic;

   function Output_Position
     (Object : Encoder) return Streams.Destination_Position_Result
   is
     (Streams.Position (Object.Output.all));

   overriding procedure Finalize (Resources : in out Encoder_Resources) is
   begin
      Resource_Management.Release (Resources);
   end Finalize;

   function Invalid_Transition (Object : Encoder) return Results.Result is
   begin
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            Internal.Diagnostics.At_Destination (Object.Output.all)));
   end Invalid_Transition;

   function Fail (Object : in out Encoder; Item : Errors.Error) return Results.Result is
      Enriched : Errors.Error := Item;
   begin
      if not Enriched.Context.Has_Destination then
         Enriched.Context := Internal.Diagnostics.At_Destination
           (Object.Output.all, Enriched.Context);
      end if;
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Enriched;
      end if;
      Resource_Management.Release (Object);
      Object.Current_State := Failed;
      return Results.Failure (Object.Diagnostic);
   end Fail;

   function Fail_Frame
     (Object : in out Encoder;
      Item   : Errors.Error) return Results.Result
   is
      Enriched : Errors.Error := Item;
   begin
      if not Enriched.Context.Has_Frame then
         Enriched.Context.Has_Frame := True;
         Enriched.Context.Frame := Object.Frames_Written;
      end if;
      return Fail (Object, Enriched);
   end Fail_Frame;

   function Has_Extension_Capacity
     (Object : Encoder;
      Additional : Natural) return Boolean
   is
   begin
      return Session_Arithmetic.Has_Natural_Capacity
        (Object.Extensions_Written,
         Object.Constraints.Max_Extensions,
         Additional);
   end Has_Extension_Capacity;

   function Validate_Frame_Request
     (Object : Encoder;
      Info   : Frame_Info) return Results.Result
   is
      Geometry : constant Geometry_Arithmetic.Rectangle_Analysis :=
        Geometry_Arithmetic.Analyze_Rectangle
          (Info.Left,
           Info.Top,
           Info.Width,
           Info.Height,
           Object.Screen.Width,
           Object.Screen.Height);
      Additional_Extensions : constant Natural :=
        (if Object.Has_Loop and then not Object.Header_Written then 1 else 0)
        + (if Info.Control /= Frames.Default_Control then 1 else 0);
   begin
      if Object.Frames_Written >= Object.Constraints.Max_Frames then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Frames),
                Actual => Byte_Count (Object.Frames_Written) + 1,
                Limit => Frame_Count_Limit,
                others => <>)));
      elsif Geometry.Pixel_Area
        > Byte_Count (Object.Constraints.Max_Frame_Pixels)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Frame_Pixels),
                Actual => Geometry.Pixel_Area,
                Limit => Frame_Pixel_Limit,
                others => <>)));
      elsif not Geometry.Fits then
         return Results.Failure
           (Errors.Make (Errors.Frame_Out_Of_Bounds));
      elsif Object.Options.Version = Force_GIF87a
        and then Info.Control /= Frames.Default_Control
      then
         return Results.Failure
           (Errors.Make (Errors.Unsupported_Feature));
      elsif not Has_Extension_Capacity (Object, Additional_Extensions) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written)
                  + Byte_Count (Additional_Extensions),
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Validate_Frame_Request;

   function Write_Raw
     (Object : in out Encoder;
      Data : Streams.Byte_Array) return Results.Result
   is
      Outcome : Results.Result;
      Budget : constant Internal.Budget_Arithmetic.Charge_Result :=
        Internal.Budget_Arithmetic.Charge
          (Object.Bytes_Written,
           Object.Constraints.Max_Output_Bytes,
           Byte_Count (Data'Length));
   begin
      if not Budget.Accepted then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Has_Destination => Output_Position (Object).Available,
                Destination => Output_Position (Object).Value,
                Expected => Object.Constraints.Max_Output_Bytes,
                Actual => Budget.Attempted,
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      begin
         Outcome := Streams.Write_All (Object.Output.all, Data);
      exception
         when others =>
            return Results.Failure
              (Errors.Make
                 (Errors.Destination_Write_Failed,
                  (Has_Destination => Output_Position (Object).Available,
                   Destination => Output_Position (Object).Value,
                   others => <>)));
      end;
      if Results.Succeeded (Outcome) then
         Object.Bytes_Written := Budget.Total;
      end if;
      return Outcome;
   end Write_Raw;

   function Write_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result
   is
      Length : constant Natural := Natural
        (Encoding_Arithmetic.Encoded_Palette_Length
           (Encoding_Arithmetic.Palette_Length (Palette.Length)));
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
      Outcome : Results.Result;
      Palette_Length : Natural := 0;
      Size_Code : Descriptor_Arithmetic.Palette_Size_Code := 0;
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
         Palette_Length := Natural
           (Encoding_Arithmetic.Encoded_Palette_Length
              (Encoding_Arithmetic.Palette_Length (Object.Global_Palette.Length)));
         Size_Code := Descriptor_Arithmetic.Palette_Size_Code
           (Encoding_Arithmetic.Size_Code
              (Encoding_Arithmetic.Palette_Length (Palette_Length)));
      end if;
      Descriptor :=
        [Internal.Extension_Arithmetic.Low_Byte (Natural (Object.Screen.Width)),
         Internal.Extension_Arithmetic.High_Byte (Natural (Object.Screen.Width)),
         Internal.Extension_Arithmetic.Low_Byte (Natural (Object.Screen.Height)),
         Internal.Extension_Arithmetic.High_Byte (Natural (Object.Screen.Height)),
         Descriptor_Arithmetic.Encode_Logical_Screen
           (Descriptor_Arithmetic.Color_Resolution (Object.Screen.Color_Resolution),
            Object.Has_Global_Palette,
            False,
            Size_Code),
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
         if not Has_Extension_Capacity (Object, 1) then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Has_Destination => Output_Position (Object).Available,
                   Destination => Output_Position (Object).Value,
                   Expected => Byte_Count (Object.Constraints.Max_Extensions),
                   Actual => Byte_Count (Object.Extensions_Written) + 1,
                   Limit => Extension_Count_Limit,
                   others => <>)));
         end if;
         declare
            Count : constant Internal.Extension_Arithmetic.Unsigned_16_Value :=
              Internal.Extension_Arithmetic.Unsigned_16_Value (Object.Loop_Count);
            Loop_Block : constant Streams.Byte_Array :=
              [16#21#, 16#FF#, 11,
               78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
               3, 1,
               Internal.Extension_Arithmetic.Low_Byte (Count),
               Internal.Extension_Arithmetic.High_Byte (Count),
               0];
         begin
            Outcome := Write_Raw (Object, Loop_Block);
         end;
         if Results.Succeeded (Outcome) then
            Object.Extensions_Written := Object.Extensions_Written + 1;
         end if;
      end if;
      if Results.Succeeded (Outcome) then
         Object.Header_Written := True;
      end if;
      return Outcome;
   end Write_Header;

   function Initialize
     (Object : in out Encoder;
      Options : Encode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      if not State_Arithmetic.Can_Initialize
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;
      Resource_Management.Release (Object);
      if Object.Resources.Cleanup_Failed then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
         Object.Current_State := Failed;
         return Results.Failure (Object.Diagnostic);
      end if;
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
      declare
         Initial_Position : constant Streams.Destination_Position_Result :=
           Streams.Position (Object.Output.all);
      begin
         if not Initial_Position.Available then
            return Fail
              (Object, Errors.Make (Errors.Destination_Write_Failed));
         end if;
         Object.Start_Offset := Initial_Position.Value;
      end;
      Object.Bytes_Written := 0;
      Object.Compressed_Bytes_Written := 0;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      Object.Current_State := Initialized;
      return Results.Success;
   end Initialize;

   function Define_Screen (Object : in out Encoder; Screen : Screen_Info) return Results.Result is
      Pixels : constant Byte_Count := Geometry_Arithmetic.Area (Screen.Width, Screen.Height);
   begin
      if not State_Arithmetic.Can_Define_Screen
        (Object.Current_State)
      then
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
      if not State_Arithmetic.Can_Configure
        (Object.Current_State, Object.Header_Written)
      then
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
      if not State_Arithmetic.Can_Configure
        (Object.Current_State, Object.Header_Written)
      then
         return Invalid_Transition (Object);
      elsif Count > 65_535 then
         return Fail (Object, Errors.Make (Errors.Integer_Overflow));
      elsif Object.Options.Version = Force_GIF87a then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      elsif not Object.Has_Loop and then not Has_Extension_Capacity (Object, 1) then
         return Fail
           (Object,
            Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
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
   is separate;

   function Add_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result
   is
   begin
      return Extensions.Add (Object, Info, Payload);
   end Add_Extension;

   function Add_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
   begin
      return Extensions.Add_Exact (Object, Info, Payload, Chunk_Lengths);
   end Add_Extension_Exact;

   function Add_Truecolor_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Source : Images.Image_View;
      Options : Quantization.Quantize_Options := Quantization.Default_Options) return Results.Result
   is separate;

   function Finish (Object : in out Encoder) return Results.Result is
      Outcome : Results.Result;
      Flush_Error : Errors.Error;
   begin
      if Object.Current_State = Completed then
         return Results.Success;
      elsif not State_Arithmetic.Can_Finish
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw (Object, [1 => 16#3B#]);
      end if;
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Flush_Error := Streams.Flush_Safely (Object.Output.all);
      if Errors.Is_Fatal (Flush_Error) then
         return Fail (Object, Flush_Error);
      end if;
      Object.Current_State := Completed;
      return Results.Success;
   end Finish;

   function Cancel (Object : in out Encoder) return Results.Result is
   begin
      if State_Arithmetic.Can_Cancel (Object.Current_State) then
         if Object.Current_State /= Cancelled then
            Resource_Management.Release (Object);
            if Object.Resources.Cleanup_Failed then
               Object.Current_State := Failed;
               Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
               return Results.Failure (Object.Diagnostic);
            end if;
            Object.Current_State := Cancelled;
            Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
         end if;
         return Results.Success;
      elsif Object.Current_State = Failed then
         return Results.Failure (Object.Diagnostic);
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
      Resource_Management.Release (Object);
      if Object.Resources.Cleanup_Failed
        and then Object.Diagnostic.Code = Errors.No_Error
      then
         Object.Diagnostic := Errors.Make (Errors.Internal_Invariant_Failed);
      end if;
      Object.Current_State := Finalized;
   end Finalize;
end Giflib.Encoding;
