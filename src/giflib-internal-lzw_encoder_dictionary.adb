with Giflib.Internal.Diagnostics;
with Giflib.Internal.LZW_Work;

package body Giflib.Internal.LZW_Encoder_Dictionary is
   function Is_Initialized (Object : Dictionary) return Boolean is
     (Object.Current_Generation /= 0);

   function Occupied_Count (Object : Dictionary) return Natural is
     (Object.Occupied);

   function Is_Occupied
     (Object : Dictionary;
      Slot : Slot_Index) return Boolean is
     (Object.Current_Generation /= 0
      and then Object.Slot_Generation (Slot) = Object.Current_Generation);

   function Matches
     (Object : Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte) return Boolean is
     (Is_Occupied (Object, Slot)
      and then Object.Prefix_Key (Slot) = Prefix
      and then Object.Suffix_Key (Slot) = Suffix);

   function Clear
     (Object : in out Dictionary;
      Work : in out Work_Budgets.Meter;
      Destination : Streams.Destination'Class) return Results.Result
   is
      Full_Reset : constant Boolean :=
        Object.Current_Generation = Natural'Last;
      Outcome : constant Results.Result := LZW_Work.Charge
        (Destination, Work, (if Full_Reset then Hash_Size else 1));
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Full_Reset then
         Object.Slot_Generation := [others => 0];
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
      Position : Slot_Index := Slot_Index
        (LZW_Arithmetic.Hash_Start
           (Prefix, Suffix));
      Outcome : Results.Result;
   begin
      for Probe in 1 .. Hash_Size loop
         Outcome := LZW_Work.Charge (Destination, Work, 1);
         if not Results.Succeeded (Outcome) then
            return
              (Kind => Lookup_Failure, Error => Outcome.First_Error);
         elsif not Is_Occupied (Object, Position) then
            return (Kind => Lookup_Miss, Slot => Position);
         elsif Matches (Object, Position, Prefix, Suffix) then
            return (Kind => Lookup_Hit, Slot => Position);
         end if;
         Position := Slot_Index
           (LZW_Arithmetic.Next_Hash_Slot
              (LZW_Arithmetic.Hash_Slot (Position)));
      end loop;
      return
        (Kind => Lookup_Failure,
         Error =>
           Errors.Make
             (Errors.Internal_Invariant_Failed,
              Diagnostics.At_Destination (Destination)));
   end Find;

   procedure Insert
     (Object : in out Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Code : LZW_Arithmetic.Code_Value) is
   begin
      Object.Slot_Generation (Slot) := Object.Current_Generation;
      Object.Prefix_Key (Slot) := Prefix;
      Object.Suffix_Key (Slot) := Suffix;
      Object.Code_Value (Slot) := Code;
      Object.Occupied := Object.Occupied + 1;
   end Insert;

   function Code_At
     (Object : Dictionary;
      Slot : Slot_Index) return LZW_Arithmetic.Code_Value is
     (Object.Code_Value (Slot));
end Giflib.Internal.LZW_Encoder_Dictionary;
