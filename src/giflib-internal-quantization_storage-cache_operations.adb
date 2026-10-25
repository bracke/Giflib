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
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
   is
      Accepted : Boolean;
      procedure Clear (Cache : in out Cache_Array) is
      begin
         Cache := [others => (others => <>)];
      end Clear;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return Outcomes.Budgeted_Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Cache_Capacity), Accepted);
      if not Accepted then
         return Outcomes.Budgeted_Work_Limit;
      end if;
      Nearest_Cache_Ownership.Update
        (Object.Nearest_Cache_Data, Clear'Access);
      return Outcomes.Budgeted_Ready;
   end Reset;

   function Probe
     (Object : in out Resources;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
   is
      Start : Natural;
      Accepted : Boolean;
      Result : Probe_Result;

      procedure Search (Cache : Cache_Array) is
         Slot : Natural;
      begin
         for Offset in 0 .. Cache_Probe_Limit - 1 loop
            Slot := (Start + Offset) mod Cache_Capacity;
            if not Cache (Slot).Used then
               Result :=
                 (Status => Outcomes.Budgeted_Ready,
                  Found => False,
                  Value => 0,
                  Store_Slot => Slot);
               return;
            elsif Cache (Slot).Key = Key then
               Result :=
                 (Status => Outcomes.Budgeted_Ready,
                  Found => True,
                  Value => Cache (Slot).Value,
                  Store_Slot => Slot);
               return;
            end if;
         end loop;
         Result :=
           (Status => Outcomes.Budgeted_Ready,
            Found => False,
            Value => 0,
            Store_Slot => Start);
      end Search;
   begin
      if not Nearest_Cache_Allocated (Object) or else Key > Cache_Key_Last then
         return (others => <>);
      end if;
      Work_Budgets.Try_Charge
        (Work, Byte_Count (Cache_Probe_Limit), Accepted);
      if not Accepted then
         return (Status => Outcomes.Budgeted_Work_Limit, others => <>);
      end if;
      Start := Cache_Start (Key);
      Nearest_Cache_Ownership.Query
        (Object.Nearest_Cache_Data, Search'Access);
      return Result;
   end Probe;

   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status is
      procedure Write (Cache : in out Cache_Array) is
      begin
         Cache (Slot) := (Used => True, Key => Key, Value => Value);
      end Write;
   begin
      if not Nearest_Cache_Allocated (Object)
        or else Slot >= Cache_Capacity
        or else Key > Cache_Key_Last
      then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Nearest_Cache_Ownership.Update
        (Object.Nearest_Cache_Data, Write'Access);
      return Outcomes.Storage_Ready;
   end Store;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
