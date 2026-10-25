with Ada.Finalization;
with Giflib.Internal.Owned_Arrays;
with Giflib.Internal.Owned_Objects;
with Giflib.Internal.Ownership;
with Giflib.Internal.Quantization_Dithering;
with Giflib.Internal.Quantization_Palette;

package Giflib.Internal.Quantization_Storage is
   pragma Preelaborate;

   subtype Histogram_State is Quantization_Palette.Histogram_State;
   package Histogram_Ownership is new Owned_Objects (Histogram_State);
   subtype Histogram_State_Access is Histogram_Ownership.Element_Access;

   Nearest_Cache_Size : constant := 4_096;
   type Nearest_Cache_Entry is record
      Used : Boolean := False;
      Key : Natural range 0 .. 16#FF_FF_FF# := 0;
      Value : Palette_Index := 0;
   end record;
   type Nearest_Cache_Array is
     array (Natural range 0 .. Nearest_Cache_Size - 1)
       of Nearest_Cache_Entry;
   package Nearest_Cache_Ownership is new Owned_Objects
     (Nearest_Cache_Array);
   subtype Nearest_Cache_Access is Nearest_Cache_Ownership.Element_Access;

   subtype Error_Array is Quantization_Dithering.Error_Array;
   package Error_Ownership is new Owned_Arrays
     (Natural, Long_Integer, Error_Array, 0);
   subtype Error_Array_Access is Error_Ownership.Element_Array_Access;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Histogram
     (Object : aliased in out Resources)
      return not null access Histogram_Ownership.Handle;
   function Nearest_Cache
     (Object : aliased in out Resources)
      return not null access Nearest_Cache_Ownership.Handle;
   function Errors
     (Object : aliased in out Resources)
      return not null access Error_Ownership.Handle;
   function Budget
     (Object : aliased in out Resources)
      return not null access Ownership.Byte_Budget;
   function Allocated_Bytes (Object : Resources) return Byte_Count;
   function Cleanup_Succeeded (Object : Resources) return Boolean;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   type Resources is new Ada.Finalization.Limited_Controlled with record
      Histogram_Data : aliased Histogram_Ownership.Handle;
      Nearest_Cache_Data : aliased Nearest_Cache_Ownership.Handle;
      Error_Data : aliased Error_Ownership.Handle;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Cleanup_Failed : Boolean := False;
   end record;
end Giflib.Internal.Quantization_Storage;
