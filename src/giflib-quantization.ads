with Giflib.Images;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

private with Giflib.Internal.Quantization_Dithering;
private with Giflib.Internal.Quantization_Palette;
private with Giflib.Internal.Ownership;
private with Ada.Finalization;

package Giflib.Quantization is
   pragma Preelaborate;

   type Dither_Mode is (No_Dither, Floyd_Steinberg);
   type Palette_Strategy is (Generate_Palette, Use_Fixed_Palette);

   type Quantize_Options is record
      Maximum_Colors : Natural range 2 .. 256 := 256;
      Dither : Dither_Mode := No_Dither;
      Strategy : Palette_Strategy := Generate_Palette;
      Fixed_Palette : Palettes.Palette := (others => <>);
      Use_Transparency : Boolean := True;
      Alpha_Threshold : Byte := 127;
      Fixed_Transparent_Index : Palette_Index := 0;
   end record;

   Default_Options : constant Quantize_Options := (others => <>);

   type Workspace is limited private;

   --  Source and Indexed_Pixels remain caller-owned. Indexed_Pixels must contain
   --  exactly Width * Height bytes. Alpha <= Alpha_Threshold becomes transparent
   --  when transparency is enabled; generated palettes reserve index zero.
   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   --  This overload retains bounded temporary storage for subsequent calls.
   function Quantize
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   function Allocated_Bytes (Context : Workspace) return Byte_Count;
   function Cleanup_Succeeded (Context : Workspace) return Boolean;
   procedure Finalize (Context : in out Workspace);

private
   subtype Histogram_State is
     Internal.Quantization_Palette.Histogram_State;
   type Histogram_State_Access is access Histogram_State;

   Nearest_Cache_Size : constant := 4_096;
   type Nearest_Cache_Entry is record
      Used : Boolean := False;
      Key : Natural range 0 .. 16#FF_FF_FF# := 0;
      Value : Palette_Index := 0;
   end record;
   type Nearest_Cache_Array is
     array (Natural range 0 .. Nearest_Cache_Size - 1) of Nearest_Cache_Entry;
   type Nearest_Cache_Access is access Nearest_Cache_Array;

   subtype Error_Array is Internal.Quantization_Dithering.Error_Array;
   type Error_Array_Access is access Error_Array;
   type Workspace_Resources is new Ada.Finalization.Limited_Controlled with record
      Histogram : Histogram_State_Access := null;
      Nearest_Cache : Nearest_Cache_Access := null;
      Errors : Error_Array_Access := null;
      Allocation_Budget : aliased Internal.Ownership.Byte_Budget;
      Cleanup_Failed : Boolean := False;
   end record;
   overriding procedure Finalize (Resources : in out Workspace_Resources);

   type Workspace is limited record
      Resources : Workspace_Resources;
      Allocation_Fault : aliased Internal.Ownership.Fault_State;
   end record;

   function Quantize_With_Resources
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result;
end Giflib.Quantization;
