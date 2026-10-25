with Giflib.Images;
with Giflib.Limits;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;

private with Giflib.Internal.Quantization_Dithering;
private with Giflib.Internal.Quantization_Palette;
private with Giflib.Internal.Ownership;
private with Giflib.Internal.Owned_Arrays;
private with Giflib.Internal.Owned_Objects;
private with Ada.Finalization;

package Giflib.Quantization is
   pragma Preelaborate;

   type Dither_Mode is (No_Dither, Floyd_Steinberg);
   type Palette_Strategy is (Generate_Palette, Use_Fixed_Palette);

   type Palette_Options
     (Strategy : Palette_Strategy := Generate_Palette) is record
      case Strategy is
         when Generate_Palette =>
            Maximum_Colors : Natural range 2 .. 256 := 256;
         when Use_Fixed_Palette =>
            Fixed_Palette : Palettes.Palette;
            Fixed_Transparent_Index : Palette_Index := 0;
      end case;
   end record;

   type Transparency_Options (Enabled : Boolean := True) is record
      case Enabled is
         when True =>
            Alpha_Threshold : Byte := 127;
         when False =>
            null;
      end case;
   end record;

   type Quantize_Options is record
      Dither : Dither_Mode := No_Dither;
      Palette : Palette_Options;
      Transparency : Transparency_Options;
   end record;

   Default_Options : constant Quantize_Options := (others => <>);

   type Transparency_Result (Present : Boolean := False) is record
      case Present is
         when True =>
            Index : Palette_Index := 0;
         when False =>
            null;
      end case;
   end record;

   type Quantization_Result is record
      Palette : Palettes.Palette;
      Transparency : Transparency_Result;
   end record;

   type Workspace is limited private;

   --  Source and Indexed_Pixels remain caller-owned. Indexed_Pixels must contain
   --  exactly Width * Height bytes. Alpha <= Alpha_Threshold becomes transparent
   --  when transparency is enabled; generated palettes reserve index zero.
   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output : out Quantization_Result;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   --  This overload retains bounded temporary storage for subsequent calls.
   function Quantize
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output : out Quantization_Result;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   function Allocated_Bytes (Context : Workspace) return Byte_Count;
   function Cleanup_Succeeded (Context : Workspace) return Boolean;
   procedure Finalize (Context : in out Workspace);

private
   subtype Histogram_State is
     Internal.Quantization_Palette.Histogram_State;
   package Histogram_Ownership is new Internal.Owned_Objects (Histogram_State);
   subtype Histogram_State_Access is Histogram_Ownership.Element_Access;

   Nearest_Cache_Size : constant := 4_096;
   type Nearest_Cache_Entry is record
      Used : Boolean := False;
      Key : Natural range 0 .. 16#FF_FF_FF# := 0;
      Value : Palette_Index := 0;
   end record;
   type Nearest_Cache_Array is
     array (Natural range 0 .. Nearest_Cache_Size - 1) of Nearest_Cache_Entry;
   package Nearest_Cache_Ownership is new Internal.Owned_Objects
     (Nearest_Cache_Array);
   subtype Nearest_Cache_Access is Nearest_Cache_Ownership.Element_Access;

   subtype Error_Array is Internal.Quantization_Dithering.Error_Array;
   package Error_Ownership is new Internal.Owned_Arrays
     (Natural, Long_Integer, Error_Array, 0);
   subtype Error_Array_Access is Error_Ownership.Element_Array_Access;
   type Workspace_Resources is new Ada.Finalization.Limited_Controlled with record
      Histogram : Histogram_Ownership.Handle;
      Nearest_Cache : Nearest_Cache_Ownership.Handle;
      Errors : Error_Ownership.Handle;
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
      Output : out Quantization_Result;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result;
end Giflib.Quantization;
