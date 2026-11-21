with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Encoder_Dictionary is
   use type Interfaces.Unsigned_32;

   Generation_Shift : constant := 20;

   function Pack_Key
     (Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte) return Packed_Key is
     (Packed_Key (Natural (Prefix) * 256 + Natural (Suffix)));
   pragma Inline_Always (Pack_Key);

   function Pack_Entry
     (Generation_Value : Generation;
      Key : Packed_Key) return Interfaces.Unsigned_32 is
     (Interfaces.Shift_Left
        (Interfaces.Unsigned_32 (Generation_Value), Generation_Shift)
      or Interfaces.Unsigned_32 (Key));
   pragma Inline_Always (Pack_Entry);

   function Entry_Generation
     (Stored_Entry : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is
     (Interfaces.Shift_Right (Stored_Entry, Generation_Shift));
   pragma Inline_Always (Entry_Generation);

   function Mix_Key (Key : Packed_Key) return Interfaces.Unsigned_32 is
      Mixed : Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Key);
   begin
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 11);
      Mixed := Mixed * 16#9E37_79B1#;
      return Mixed xor Interfaces.Shift_Right (Mixed, 16);
   end Mix_Key;
   pragma Inline_Always (Mix_Key);

   function Hash_Start (Mixed : Interfaces.Unsigned_32) return Slot_Index is
     (Slot_Index
        (Natural
           (Mixed and Interfaces.Unsigned_32 (Hash_Size - 1))));
   pragma Inline_Always (Hash_Start);

   function Hash_Step (Mixed : Interfaces.Unsigned_32) return Positive is
     (2
        * (Natural
             (Interfaces.Shift_Right (Mixed, 13)
                and Interfaces.Unsigned_32 (Hash_Size - 1))
           / 2)
      + 1);
   pragma Inline_Always (Hash_Step);

   function Is_Initialized (Object : Dictionary) return Boolean is
     (Object.Current_Generation /= 0);

   function Occupied_Count (Object : Dictionary) return Natural is
     (Object.Occupied);

   function Is_Occupied
     (Object : Dictionary;
      Slot : Slot_Index) return Boolean is
     (Object.Current_Generation /= 0
      and then
        Entry_Generation (Object.Entries (Slot)) =
          Interfaces.Unsigned_32 (Object.Current_Generation));

   function Matches
     (Object : Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte) return Boolean is
     (Is_Occupied (Object, Slot)
      and then
        Object.Entries (Slot) =
          Pack_Entry (Object.Current_Generation, Pack_Key (Prefix, Suffix)));

   function Clear
     (Object : in out Dictionary;
      Work : in out Work_Budgets.Meter;
      Destination : Streams.Destination'Class) return Results.Result
   is
      Full_Reset : constant Boolean :=
        Object.Current_Generation = Generation'Last;
   begin
      if not LZW_Work.Try_Charge
        (Work, (if Full_Reset then Hash_Size else 1))
      then
         return LZW_Work.Failure (Destination, Work);
      elsif Full_Reset then
         Object.Entries := [others => 0];
         Object.Current_Generation := 1;
      else
         Object.Current_Generation := Object.Current_Generation + 1;
      end if;
      Object.Occupied := 0;
      return Results.Success;
   end Clear;

   function Find
     (Object : Dictionary;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Work : in out Work_Budgets.Meter;
      Destination : Streams.Destination'Class) return Lookup_Result
   is
      Probe_Work : Byte_Count;
      Slot : Slot_Index;
      Kind : constant Validated_Lookup_Kind :=
        Find_Validated (Object, Prefix, Suffix, Slot, Probe_Work);
   begin
      if not LZW_Work.Try_Charge (Work, Probe_Work) then
         return
           (Kind => Lookup_Failure,
            Error => LZW_Work.Failure (Destination, Work).First_Error);
      end if;
      return
        (case Kind is
           when Validated_Hit => (Kind => Lookup_Hit, Slot => Slot),
           when Validated_Miss => (Kind => Lookup_Miss, Slot => Slot),
           when Validated_Failure =>
             (Kind => Lookup_Failure,
              Error => Errors.Make
                (Errors.Internal_Invariant_Failed,
                 Diagnostics.At_Destination (Destination))));
   end Find;

   function Find_Validated
     (Object : Dictionary;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Slot : out Slot_Index;
      Probe_Work : out Byte_Count) return Validated_Lookup_Kind
   is
      Key : constant Packed_Key := Pack_Key (Prefix, Suffix);
      Stored_Entry : constant Interfaces.Unsigned_32 :=
        Pack_Entry (Object.Current_Generation, Key);
      Mixed : constant Interfaces.Unsigned_32 := Mix_Key (Key);
      Position : Slot_Index := Hash_Start (Mixed);
      Step : constant Positive := Hash_Step (Mixed);
      Current_Entry : Interfaces.Unsigned_32;
   begin
      Slot := Position;
      Probe_Work := 0;
      for Probe in 1 .. Hash_Size loop
         Probe_Work := Byte_Count (Probe);
         Current_Entry := Object.Entries (Position);
         if Current_Entry = Stored_Entry then
            Slot := Position;
            return Validated_Hit;
         elsif Entry_Generation (Current_Entry) /=
           Interfaces.Unsigned_32 (Object.Current_Generation)
         then
            Slot := Position;
            return Validated_Miss;
         end if;
         Position := Slot_Index
           ((Natural (Position) + Step) mod Hash_Size);
      end loop;
      return Validated_Failure;
   end Find_Validated;

   procedure Insert
     (Object : in out Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Code : LZW_Arithmetic.Code_Value) is
   begin
      Object.Entries (Slot) :=
        Pack_Entry (Object.Current_Generation, Pack_Key (Prefix, Suffix));
      Object.Code_Value (Slot) := Stored_Code (Code);
      Object.Occupied := Object.Occupied + 1;
   end Insert;

   function Code_At
     (Object : Dictionary;
      Slot : Slot_Index) return LZW_Arithmetic.Code_Value is
     (LZW_Arithmetic.Code_Value (Object.Code_Value (Slot)));
end Giflib.Internal.LZW_Encoder_Dictionary;
