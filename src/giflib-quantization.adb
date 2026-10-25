with Giflib.Errors;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Dithering;
with Giflib.Internal.Quantization_Palette;
with Giflib.Internal.Quantization_Pixels;

package body Giflib.Quantization is
   use type Internal.Ownership.Allocation_Status;
   use type Palettes.RGB_Color;

   package Arithmetic renames Internal.Quantization_Arithmetic;
   package Buffer_Arithmetic renames Internal.Quantization_Buffer_Arithmetic;
   package Dithering renames Internal.Quantization_Dithering;
   package Palette_Builder renames Internal.Quantization_Palette;
   package Pixels renames Internal.Quantization_Pixels;
   package Storage renames Internal.Quantization_Storage;
   package Histogram_Ownership renames Storage.Histogram_Ownership;
   package Nearest_Cache_Ownership renames Storage.Nearest_Cache_Ownership;
   package Error_Ownership renames Storage.Error_Ownership;
   subtype Histogram_State_Access is Storage.Histogram_State_Access;
   subtype Nearest_Cache_Access is Storage.Nearest_Cache_Access;
   subtype Error_Array_Access is Storage.Error_Array_Access;
   Nearest_Cache_Size : constant := Storage.Nearest_Cache_Size;
   subtype Histogram_Index is Palette_Builder.Histogram_Index;

   subtype Work_Tracker is Internal.Work_Budgets.Meter;

   function Charge
     (Tracker : in out Work_Tracker;
      Amount : Byte_Count := 1) return Boolean
   is
      Accepted : Boolean;
   begin
      Internal.Work_Budgets.Try_Charge (Tracker, Amount, Accepted);
      return Accepted;
   end Charge;

   Nearest_Cache_Probe_Limit : constant := 8;

   function Allocated_Bytes (Context : Workspace) return Byte_Count is
   begin
      return Storage.Allocated_Bytes (Context.Resources);
   end Allocated_Bytes;

   function Cleanup_Succeeded (Context : Workspace) return Boolean is
     (Storage.Cleanup_Succeeded (Context.Resources));

   procedure Finalize (Context : in out Workspace) is
   begin
      Storage.Release (Context.Resources);
   end Finalize;

   function Allocation_Result
     (Constraints : Limits.Limit_Set;
      Outcome : Internal.Ownership.Allocation_Outcome) return Results.Result
   is
   begin
      return Results.Failure
        (Internal.Resource_Diagnostics.Allocation_Error
           (Outcome,
            Constraints.Max_Allocation_Bytes,
            Outcome.Attempted));
   end Allocation_Result;

   function Ensure_Nearest_Cache
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Storage.Budget (Context.Resources).all;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Nearest_Cache_Ownership.Is_Allocated
        (Storage.Nearest_Cache (Context.Resources).all)
      then
         return Results.Success;
      end if;
      Outcome := Nearest_Cache_Ownership.Ensure
        (Storage.Nearest_Cache (Context.Resources).all,
         Budget,
         Fault,
         Constraints.Max_Allocation_Bytes);
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Constraints, Outcome);
      end if;
      return Results.Success;
   end Ensure_Nearest_Cache;

   function Ensure_Histogram
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Storage.Budget (Context.Resources).all;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Histogram_Ownership.Is_Allocated
        (Storage.Histogram (Context.Resources).all)
      then
         return Results.Success;
      end if;
      Outcome := Histogram_Ownership.Ensure
        (Storage.Histogram (Context.Resources).all,
         Budget,
         Fault,
         Constraints.Max_Allocation_Bytes);
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Constraints, Outcome);
      end if;
      return Results.Success;
   end Ensure_Histogram;

   function Ensure_Error_Buffer
     (Context : in out Workspace;
      Width : Image_Width;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Required_Length : constant Positive :=
        Buffer_Arithmetic.Error_Buffer_Length (Width);
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Storage.Budget (Context.Resources).all;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Error_Ownership.Length (Storage.Errors (Context.Resources).all)
        >= Required_Length
      then
         return Results.Success;
      end if;
      Outcome := Error_Ownership.Ensure
        (Storage.Errors (Context.Resources).all,
         Budget,
         Fault,
         First => 0,
         Last => Required_Length - 1,
         Maximum => Constraints.Max_Allocation_Bytes);
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Result (Constraints, Outcome);
      end if;
      return Results.Success;
   end Ensure_Error_Buffer;

   function Validate_Request
     (Context : Workspace;
      Source : Images.Image_View;
      Indexed_Length : Natural;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Pixel_Total : Byte_Count) return Results.Result
   is
      Outcome : constant Results.Result := Images.Validate (Source);
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Source.Format = Indexed_8 then
         return Results.Failure
           (Giflib.Errors.Make (Giflib.Errors.Unsupported_Feature));
      elsif Byte_Count (Indexed_Length) /= Pixel_Total then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Buffer_Size_Mismatch,
               (Expected => Pixel_Total,
                Actual => Byte_Count (Indexed_Length),
                others => <>)));
      elsif Pixel_Total > Byte_Count (Constraints.Max_Frame_Pixels) then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Byte_Count (Constraints.Max_Frame_Pixels),
                Actual => Pixel_Total,
                Limit => Frame_Pixel_Limit,
                others => <>)));
      elsif Options.Palette.Strategy = Use_Fixed_Palette
        and then Options.Palette.Fixed_Palette.Length < 2
      then
         return Results.Failure
           (Giflib.Errors.Make (Giflib.Errors.Missing_Color_Table));
      elsif Allocated_Bytes (Context) > Constraints.Max_Allocation_Bytes then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Constraints.Max_Allocation_Bytes,
                Actual => Allocated_Bytes (Context),
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Validate_Request;

   function Map_Pixels
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : Palettes.Palette;
      Has_Transparency : Boolean;
      Transparent_Index : Palette_Index;
      Generated_Start : Natural;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Tracker : in out Work_Tracker) return Results.Result
   is separate;

   function Quantize_With_Resources
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output : out Quantization_Result;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result
   is separate;

   function Quantize
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output : out Quantization_Result;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      return Quantize_With_Resources
        (Context, Source, Indexed_Pixels, Output, Options, Constraints);
   end Quantize;

   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output : out Quantization_Result;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      Context : Workspace;
   begin
      return Quantize
        (Context, Source, Indexed_Pixels, Output, Options, Constraints);
   end Quantize;
end Giflib.Quantization;
