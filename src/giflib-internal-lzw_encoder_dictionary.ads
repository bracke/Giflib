with Giflib.Errors;
with Giflib.Internal.LZW_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Internal.LZW_Encoder_Dictionary
  with Preelaborate
is
   Hash_Size : constant := LZW_Arithmetic.Hash_Size;
   subtype Slot_Index is Natural range 0 .. Hash_Size - 1;

   type Dictionary is limited private;

   function Is_Initialized (Object : Dictionary) return Boolean;
   function Occupied_Count (Object : Dictionary) return Natural;
   function Is_Occupied
     (Object : Dictionary;
      Slot : Slot_Index) return Boolean;
   function Matches
     (Object : Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte) return Boolean;

   function Clear
     (Object : in out Dictionary;
      Work : in out Work_Budgets.Meter;
      Destination : Streams.Destination'Class) return Results.Result
     with Post =>
       (if Results.Succeeded (Clear'Result)
        then Is_Initialized (Object)
          and then Occupied_Count (Object) = 0);

   type Lookup_Kind is (Lookup_Hit, Lookup_Miss, Lookup_Failure);
   type Lookup_Result (Kind : Lookup_Kind) is record
      case Kind is
         when Lookup_Hit | Lookup_Miss =>
            Slot : Slot_Index;
         when Lookup_Failure =>
            Error : Errors.Error;
      end case;
   end record;

   function Find
     (Object : Dictionary;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Work : in out Work_Budgets.Meter;
      Destination : Streams.Destination'Class) return Lookup_Result
     with Pre => Is_Initialized (Object),
          Post =>
       (if Find'Result.Kind = Lookup_Hit
        then Matches (Object, Find'Result.Slot, Prefix, Suffix)
        elsif Find'Result.Kind = Lookup_Miss
        then not Is_Occupied (Object, Find'Result.Slot));

   function Code_At
     (Object : Dictionary;
      Slot : Slot_Index) return LZW_Arithmetic.Code_Value
     with Pre => Is_Initialized (Object)
                 and then Is_Occupied (Object, Slot);

   procedure Insert
     (Object : in out Dictionary;
      Slot : Slot_Index;
      Prefix : LZW_Arithmetic.Code_Value;
      Suffix : Byte;
      Code : LZW_Arithmetic.Code_Value)
     with Pre => Is_Initialized (Object)
                 and then not Is_Occupied (Object, Slot)
                 and then Occupied_Count (Object) < Hash_Size,
          Post => Is_Occupied (Object, Slot)
                  and then Matches (Object, Slot, Prefix, Suffix)
                  and then Code_At (Object, Slot) = Code;

private
   type Code_Table is array (Slot_Index) of LZW_Arithmetic.Code_Value;
   type Byte_Table is array (Slot_Index) of Byte;
   type Generation_Table is array (Slot_Index) of Natural;

   type Dictionary is limited record
      Prefix_Key : Code_Table := [others => 0];
      Suffix_Key : Byte_Table := [others => 0];
      Code_Value : Code_Table := [others => 0];
      Slot_Generation : Generation_Table := [others => 0];
      Current_Generation : Natural := 0;
      Occupied : Natural range 0 .. Hash_Size := 0;
   end record;
end Giflib.Internal.LZW_Encoder_Dictionary;
