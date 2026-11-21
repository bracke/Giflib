with Interfaces;

package body Giflib.Internal.Quantization_Storage.Cache_Operations is
   use type Interfaces.Unsigned_32;
   use type Outcomes.Storage_Status;
   Cache_Probe_Limit : constant := Natural (Probe_Work_Amount);
   Cache_Key_Last : constant := 16#FF_FF_FF#;

   function Cache_Start (Key : Natural) return Natural is
      Mixed : Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Key);
   begin
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 12);
      Mixed := Mixed * 16#9E37_79B1#;
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 16);
      return Natural (Mixed mod Interfaces.Unsigned_32 (Cache_Capacity));
   end Cache_Start;
   pragma Inline_Always (Cache_Start);

   function Update
     (Object : in out Resources;
      Process : not null access procedure
        (State : in out Cache_State;
         Current_Epoch : Epoch)) return Outcomes.Storage_Status
   is
      procedure Apply (State : in out Cache_Array) is
      begin
         Process (State, Object.Current_Cache_Epoch);
      end Apply;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Nearest_Cache_Ownership.Update
        (Object.Nearest_Cache_Data, Apply'Access);
      return Outcomes.Storage_Ready;
   end Update;

   function Reset
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Outcomes.Budgeted_Status
   is
      Accepted : Boolean;
      Wraps : constant Boolean := Object.Current_Cache_Epoch = Cache_Epoch'Last;
      procedure Clear (Cache : in out Cache_Array) is
      begin
         Cache := [others => (others => <>)];
      end Clear;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return Outcomes.Budgeted_Invariant_Failure;
      end if;
      Work_Budgets.Try_Charge
        (Work, (if Wraps then Byte_Count (Cache_Capacity) else 1), Accepted);
      if not Accepted then
         return Outcomes.Budgeted_Work_Limit;
      end if;
      if Wraps then
         Nearest_Cache_Ownership.Update
           (Object.Nearest_Cache_Data, Clear'Access);
         Object.Current_Cache_Epoch := 1;
      else
         Object.Current_Cache_Epoch := Object.Current_Cache_Epoch + 1;
      end if;
      return Outcomes.Budgeted_Ready;
   end Reset;

   function Probe
     (State : Cache_State;
      Current_Epoch : Epoch;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
   is
      Accepted : Boolean;
      Probe_Work : Byte_Count;
      Value : Palette_Index;
      Store_Slot : Natural;
      Kind : Probe_Kind;
   begin
      if Key > Cache_Key_Last then
         return (Kind => Probe_Invariant_Failure);
      end if;
      Work_Budgets.Try_Charge
        (Work, Probe_Work_Amount, Accepted);
      if not Accepted then
         return (Kind => Probe_Work_Limit);
      end if;
      Kind := Probe_Validated
        (State, Current_Epoch, Key, Value, Store_Slot, Probe_Work);
      return
        (case Kind is
           when Probe_Hit => (Kind => Probe_Hit, Value => Value),
           when Probe_Miss =>
             (Kind => Probe_Miss, Store_Slot => Store_Slot),
           when Probe_Work_Limit | Probe_Invariant_Failure =>
             (Kind => Probe_Invariant_Failure));
   end Probe;

   function Probe_Validated
     (State : Cache_State;
      Current_Epoch : Epoch;
      Key : Natural;
      Value : out Palette_Index;
      Store_Slot : out Natural;
      Probe_Work : out Byte_Count) return Probe_Kind
   is
      Start : constant Natural := Cache_Start (Key);
      Slot : Natural;
   begin
      Value := 0;
      Store_Slot := Start;
      Probe_Work := 0;
      for Offset in 0 .. Cache_Probe_Limit - 1 loop
         Probe_Work := Byte_Count (Offset + 1);
         Slot := (Start + Offset) mod Cache_Capacity;
         if State (Slot).Epoch /= Current_Epoch then
            Store_Slot := Slot;
            return Probe_Miss;
         elsif State (Slot).Key = Key then
            Value := State (Slot).Value;
            return Probe_Hit;
         end if;
      end loop;
      return Probe_Miss;
   end Probe_Validated;

   function Probe
     (Object : in out Resources;
      Key : Natural;
      Work : in out Work_Budgets.Meter) return Probe_Result
   is
      Result : Probe_Result;
      Status : Outcomes.Storage_Status;
      procedure Search (State : in out Cache_State; Current_Epoch : Epoch) is
      begin
         Result := Probe (State, Current_Epoch, Key, Work);
      end Search;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return (Kind => Probe_Invariant_Failure);
      end if;
      Status := Update (Object, Search'Access);
      if Status /= Outcomes.Storage_Ready then
         return (Kind => Probe_Invariant_Failure);
      end if;
      return Result;
   end Probe;

   function Store
     (State : in out Cache_State;
      Current_Epoch : Epoch;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status is
   begin
      if Slot >= Cache_Capacity
        or else Key > Cache_Key_Last
      then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      State (Slot) :=
        (Epoch => Current_Epoch, Key => Key, Value => Value);
      return Outcomes.Storage_Ready;
   end Store;

   function Store
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Outcomes.Storage_Status
   is
      Result : Outcomes.Storage_Status := Outcomes.Storage_Invariant_Failure;
      Update_Status : Outcomes.Storage_Status;
      procedure Write (State : in out Cache_State; Current_Epoch : Epoch) is
      begin
         Result := Store (State, Current_Epoch, Slot, Key, Value);
      end Write;
   begin
      if not Nearest_Cache_Allocated (Object) then
         return Outcomes.Storage_Invariant_Failure;
      end if;
      Update_Status := Update (Object, Write'Access);
      if Update_Status /= Outcomes.Storage_Ready then
         return Update_Status;
      end if;
      return Result;
   end Store;
end Giflib.Internal.Quantization_Storage.Cache_Operations;
