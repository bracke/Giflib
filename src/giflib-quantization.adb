with Giflib.Errors;
with Giflib.Internal.Work_Budgets;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Quantization.Palette_Building;
with Giflib.Quantization.Pixel_Mapping;

package body Giflib.Quantization is
   package Storage renames Internal.Quantization_Storage;
   package Palette_Phase renames Palette_Building;
   package Mapping_Phase renames Pixel_Mapping;

   subtype Work_Tracker is Internal.Work_Budgets.Meter;

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
