separate (Giflib.Testing.Test_LZW_Encoding)
procedure Encoder_Dictionary_Enforces_Occupancy
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   package Dictionary renames Giflib.Internal.LZW_Encoder_Dictionary;
   use type Dictionary.Lookup_Kind;
   Storage : aliased Giflib.Streams.Byte_Array := [0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Object : Dictionary.Dictionary;
   Work : Giflib.Internal.Work_Budgets.Meter
     (Giflib.Byte_Count (Dictionary.Hash_Size * 2 + 10));
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Destination);
   Assert
     (not Dictionary.Is_Initialized (Object),
      "encoder dictionary unexpectedly started initialized");
   Outcome := Dictionary.Clear (Object, Work, Destination);
   Assert
     (Giflib.Results.Succeeded (Outcome)
      and then Dictionary.Is_Initialized (Object)
      and then Dictionary.Occupied_Count (Object) = 0,
      "encoder dictionary did not start an empty generation");
   declare
      Lookup : constant Dictionary.Lookup_Result :=
        Dictionary.Find (Object, 0, 0, Work, Destination);
   begin
      Assert
        (Lookup.Kind = Dictionary.Lookup_Miss
         and then not Dictionary.Is_Occupied (Object, Lookup.Slot),
         "encoder dictionary returned an occupied insertion slot");
      Dictionary.Insert (Object, Lookup.Slot, 0, 0, 6);
   end;
   declare
      Lookup : constant Dictionary.Lookup_Result :=
        Dictionary.Find (Object, 0, 0, Work, Destination);
   begin
      Assert
        (Lookup.Kind = Dictionary.Lookup_Hit
         and then Dictionary.Matches (Object, Lookup.Slot, 0, 0)
         and then Dictionary.Code_At (Object, Lookup.Slot) = 6,
         "encoder dictionary lost an inserted code");
   end;

   Outcome := Dictionary.Clear (Object, Work, Destination);
   Assert (Giflib.Results.Succeeded (Outcome),
           "encoder dictionary generation reset failed");
   for Index in Dictionary.Slot_Index loop
      Dictionary.Insert (Object, Index, 0, 0, 6);
   end loop;
   declare
      Lookup : constant Dictionary.Lookup_Result :=
        Dictionary.Find (Object, 1, 1, Work, Destination);
   begin
      Assert
        (Lookup.Kind = Dictionary.Lookup_Failure
         and then Lookup.Error.Code = Giflib.Errors.Internal_Invariant_Failed,
         "full encoder dictionary did not stop after one probe cycle");
   end;

   declare
      Wrap_Work : Giflib.Internal.Work_Budgets.Meter
        (Giflib.Byte_Count (Dictionary.Hash_Size + 300));
   begin
      --  The compact generation stored with each key deliberately wraps after
      --  255 dictionary clears.  Exercise the bounded full-table reset rather
      --  than relying on ordinary fixtures to happen to reach it.
      for I in 1 .. 253 loop
         Outcome := Dictionary.Clear (Object, Wrap_Work, Destination);
         Assert (Giflib.Results.Succeeded (Outcome),
                 "encoder dictionary generation advance failed");
      end loop;
      Dictionary.Insert (Object, 0, 2, 3, 7);
      Outcome := Dictionary.Clear (Object, Wrap_Work, Destination);
      Assert
        (Giflib.Results.Succeeded (Outcome)
         and then not Dictionary.Is_Occupied (Object, 0),
         "encoder dictionary generation wrap retained a stale entry");
   end;
end Encoder_Dictionary_Enforces_Occupancy;
