with Ada.Finalization;
with Giflib.Internal.Ownership;
private with Giflib.Internal.Owned_Arrays;
private with Giflib.Internal.Owned_Objects;
private with Giflib.Internal.Quantization_Dithering;
private with Giflib.Internal.Quantization_Palette;

package Giflib.Internal.Quantization_Storage is
   pragma Preelaborate;
   use type Ownership.Allocation_Status;

   type Resources is new Ada.Finalization.Limited_Controlled with private;

   function Histogram_Allocated (Object : Resources) return Boolean;
   function Nearest_Cache_Allocated (Object : Resources) return Boolean;
   function Error_Length (Object : Resources) return Natural;

   function Ensure_Histogram
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Histogram'Result.Status = Ownership.Allocation_Ready
        then Histogram_Allocated (Object));
   function Ensure_Nearest_Cache
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Nearest_Cache'Result.Status = Ownership.Allocation_Ready
        then Nearest_Cache_Allocated (Object));
   function Ensure_Errors
     (Object : in out Resources;
      Fault : in out Ownership.Fault_State;
      Last : Natural;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
     with Post =>
       (if Ensure_Errors'Result.Status = Ownership.Allocation_Ready
        then Error_Length (Object) >= Last + 1);
   function Allocated_Bytes (Object : Resources) return Byte_Count;
   function Is_Released (Object : Resources) return Boolean;
   function Cleanup_Succeeded (Object : Resources) return Boolean;

   procedure Release (Object : in out Resources);
   overriding procedure Finalize (Object : in out Resources);

private
   Cache_Capacity : constant Positive := 4_096;
   type Cache_Item is record
      Used : Boolean := False;
      Key : Natural range 0 .. 16#FF_FF_FF# := 0;
      Value : Palette_Index := 0;
   end record;
   type Cache_Array is
     array (Natural range 0 .. Cache_Capacity - 1) of Cache_Item;

   package Histogram_Ownership is new Owned_Objects
     (Quantization_Palette.Histogram_State);
   package Nearest_Cache_Ownership is new Owned_Objects
     (Cache_Array);
   package Error_Ownership is new Owned_Arrays
     (Natural, Long_Integer, Quantization_Dithering.Error_Array, 0);

   type Resources is new Ada.Finalization.Limited_Controlled with record
      Histogram_Data : Histogram_Ownership.Handle;
      Nearest_Cache_Data : Nearest_Cache_Ownership.Handle;
      Error_Data : Error_Ownership.Handle;
      Allocation_Budget : aliased Ownership.Byte_Budget;
      Cleanup_Failed : aliased Boolean := False;
   end record;
end Giflib.Internal.Quantization_Storage;
