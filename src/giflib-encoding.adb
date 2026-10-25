with Giflib.Encoding.Extensions;
with Giflib.Encoding.Resource_Management;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Container_Writer;
with Giflib.Internal.Encoding_Arithmetic;
with Giflib.Encoding.State_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Loop_Extensions;
with Giflib.Internal.Session_Arithmetic;
with Giflib.Internal.Wire_Format;

package body Giflib.Encoding is
   use type Animations.Loop_State;
   use type Errors.Error_Code;
   use type Errors.Position_State;
   use type Frames.Graphic_Control;
   use type Metadata.Extension_Kind;
   package Buffers renames Internal.Owned_Buffers;
   package Encoding_Arithmetic renames Internal.Encoding_Arithmetic;
   package Geometry_Arithmetic renames Internal.Geometry_Arithmetic;
   package Session_Arithmetic renames Internal.Session_Arithmetic;

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
      if Enriched.Context.Destination_Position.State =
        Errors.Position_Not_Checked
      then
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
      if not Enriched.Context.Frame.Present then
         Enriched.Context.Frame := Errors.Frame_At (Object.Frames_Written);
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
        (if Object.Loop_Data.State /= Animations.No_Loop_Extension
             and then not Object.Header_Written
         then 1 else 0)
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
      Written : Byte_Count;
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
               Internal.Diagnostics.At_Destination
                 (Object.Output.all,
                  (Expected => Object.Constraints.Max_Output_Bytes,
                   Actual => Budget.Attempted,
                   Limit => Output_Byte_Limit,
                   others => <>))));
      end if;
      Outcome := Streams.Write_All (Object.Output.all, Data, Written);
      Object.Bytes_Written := Object.Bytes_Written + Written;
      return Outcome;
   end Write_Raw;

   function Write_Palette
     (Object : in out Encoder;
      Palette : Palettes.Palette) return Results.Result
   is
   begin
      return Write_Raw
        (Object, Internal.Container_Writer.Palette_Data (Palette));
   end Write_Palette;

   function Write_Header (Object : in out Encoder) return Results.Result is
      Outcome : Results.Result;
   begin
      if Object.Header_Written then
         return Results.Success;
      end if;
      if Object.Options.Version = Force_GIF87a
        and then Object.Loop_Data.State /= Animations.No_Loop_Extension
      then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      end if;
      Outcome := Write_Raw
        (Object,
         Internal.Container_Writer.Signature
           (if Object.Options.Version = Force_GIF87a
            then GIF87a else GIF89a));
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw
           (Object,
            Internal.Container_Writer.Logical_Screen
              (Width => Object.Screen.Width,
               Height => Object.Screen.Height,
               Color_Resolution => Object.Screen.Color_Resolution,
               Global_Palette =>
                 (if Object.Has_Global_Palette
                  then (Present => True,
                        Length => Internal.Container_Writer.Palette_Length
                          (Object.Global_Palette.Length),
                        Sorted => False)
                  else Internal.Container_Writer.No_Palette),
               Background_Index => Object.Screen.Background_Index,
               Pixel_Aspect_Ratio => Object.Screen.Pixel_Aspect_Ratio));
      end if;
      if Results.Succeeded (Outcome) and then Object.Has_Global_Palette then
         Outcome := Write_Palette (Object, Object.Global_Palette);
      end if;
      if Results.Succeeded (Outcome)
        and then Object.Loop_Data.State /= Animations.No_Loop_Extension
      then
         if not Has_Extension_Capacity (Object, 1) then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  Internal.Diagnostics.At_Destination
                    (Object.Output.all,
                     (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                      Actual => Byte_Count (Object.Extensions_Written) + 1,
                      Limit => Extension_Count_Limit,
                      others => <>))));
         end if;
         Outcome := Write_Raw
           (Object,
            Internal.Loop_Extensions.Encode_Netscape
              (Animations.Raw_Count (Object.Loop_Data)));
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
      Object.Loop_Data := Animations.No_Loop;
      Object.Header_Written := False;
      Object.Frames_Written := 0;
      Object.Extensions_Written := 0;
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
      elsif Object.Loop_Data.State = Animations.No_Loop_Extension
        and then not Has_Extension_Capacity (Object, 1)
      then
         return Fail
           (Object,
            Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      Object.Loop_Data :=
        (if Count = 0
         then (State => Animations.Infinite_Looping)
         else (State => Animations.Finite_Loop_Count, Count => Count));
      return Results.Success;
   end Set_Loop_Count;

   function Add_Indexed_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is separate;

   function Add_Extension
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result
   is
   begin
      return Extensions.Add (Object, Descriptor, Payload);
   end Add_Extension;

   function Add_Extension_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
   begin
      return Extensions.Add_Exact
        (Object, Descriptor, Payload, Chunk_Lengths);
   end Add_Extension_Exact;

   type Descriptor_Conversion (Supported : Boolean := False) is record
      case Supported is
         when True =>
            Descriptor : Extension_Descriptor;
         when False =>
            null;
      end case;
   end record;

   function Descriptor_For
     (Info : Metadata.Extension_Info) return Descriptor_Conversion
   is
   begin
      return
        (case Info.Kind is
            when Metadata.Comment_Extension =>
              (Supported => True,
               Descriptor => (Kind => Comment_Extension)),
            when Metadata.Plain_Text_Extension =>
              (Supported => True,
               Descriptor => (Kind => Plain_Text_Extension)),
            when Metadata.Application_Extension =>
              (Supported => True,
               Descriptor => (Kind => Application_Extension)),
            when Metadata.Unknown_Extension =>
              (Supported => True,
               Descriptor => (Kind => Unknown_Extension, Label => Info.Label)),
            when Metadata.Graphic_Control_Extension =>
              (Supported => False));
   end Descriptor_For;

   function Add_Decoded_Extension
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array) return Results.Result
   is
      Conversion : constant Descriptor_Conversion := Descriptor_For (Info);
   begin
      if not Conversion.Supported then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      return Add_Extension (Object, Conversion.Descriptor, Payload);
   end Add_Decoded_Extension;

   function Add_Decoded_Extension_Exact
     (Object : in out Encoder;
      Info : Metadata.Extension_Info;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
      Conversion : constant Descriptor_Conversion := Descriptor_For (Info);
   begin
      if not Conversion.Supported then
         return Fail (Object, Errors.Make (Errors.Unsupported_Feature));
      end if;
      return Add_Extension_Exact
        (Object, Conversion.Descriptor, Payload, Chunk_Lengths);
   end Add_Decoded_Extension_Exact;

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
         Outcome := Write_Raw
           (Object, [1 => Internal.Wire_Format.Trailer]);
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
