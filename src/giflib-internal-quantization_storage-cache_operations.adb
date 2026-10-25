with Interfaces;

package body Giflib.Internal.Quantization_Storage.Cache_Operations is
   use type Interfaces.Unsigned_32;
   Cache_Probe_Limit : constant := 8;
   Cache_Key_Last : constant := 16#FF_FF_FF#;

   function Cache_Start (Key : Natural) return Natural is
      Mixed : Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Key);
   begin
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 12);
      Mixed := Mixed * 16#9E37_79B1#;
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 16);
      return Natural (Mixed mod Interfaces.Unsigned_32 (Cache_Capacity));
   end Cache_Start;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status
   is
      Accepted : Boolean;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return Operations.Operation_Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Cache_Capacity), Accepted);
      if not Accepted then
         return Operations.Operation_Work_Limit;
      end if;
      Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data).all :=
        [others => (others => <>)];
      return Operations.Operation_Ready;
   end Reset;

   function Probe
     (Object : in out Resources;
      Key : Natural) return Probe_Result
   is
      Start : Natural;
      Slot : Natural;
      Probe_Count : Natural := 0;
   begin
      if not Nearest_Cache_Allocated (Object) or else Key > Cache_Key_Last then
         return (others => <>);
      end if;
      Start := Cache_Start (Key);
      declare
         Cache : constant Nearest_Cache_Ownership.Element_Access :=
           Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data);
      begin
         for Offset in 0 .. Cache_Probe_Limit - 1 loop
            Probe_Count := Probe_Count + 1;
            Slot := (Start + Offset) mod Cache_Capacity;
            if not Cache (Slot).Used then
               return (Status => Operations.Operation_Ready, Found => False,
                       Value => 0, Store_Slot => Slot,
                       Probe_Count => Probe_Count);
            elsif Cache (Slot).Key = Key then
               return (Status => Operations.Operation_Ready, Found => True,
                       Value => Cache (Slot).Value, Store_Slot => Slot,
                       Probe_Count => Probe_Count);
            end if;
         end loop;
      end;
      return (Status => Operations.Operation_Ready, Found => False,
              Value => 0, Store_Slot => Start,
              Probe_Count => Probe_Count);
   end Probe;

   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Operation_Status is
   begin
      if not Nearest_Cache_Allocated (Object)
        or else Slot >= Cache_Capacity
        or else Key > Cache_Key_Last
      then
         return Operations.Operation_Invariant_Failure;
      end if;
      Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data).all (Slot) :=
        (Used => True, Key => Key, Value => Value);
      return Operations.Operation_Ready;
   end Store;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
