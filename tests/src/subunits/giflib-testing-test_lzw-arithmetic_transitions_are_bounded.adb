separate (Giflib.Testing.Test_LZW)
procedure Arithmetic_Transitions_Are_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.LZW_Arithmetic;
begin
   for Minimum in Arithmetic.Minimum_Code_Size loop
      declare
         State : constant Arithmetic.Initial_Code_State := Arithmetic.Initialize (Minimum);
      begin
         Assert (State.Clear_Code = 2 ** Minimum, "wrong LZW clear code");
         Assert (State.End_Code = State.Clear_Code + 1, "wrong LZW end code");
         Assert (State.First_Free_Code = State.Clear_Code + 2, "wrong first dictionary code");
         Assert (State.Width = Minimum + 1, "wrong initial LZW width");
      end;
   end loop;

   for Width in Arithmetic.Active_Code_Width range 3 .. 11 loop
      Assert
        (Arithmetic.Decoder_Width_After_Insert
           (Arithmetic.Next_Code_Value (2 ** Width), Width) = Width + 1,
         "decoder width did not advance at its boundary");
      Assert
        (Arithmetic.Encoder_Width_After_Insert
           (Arithmetic.Next_Code_Value (2 ** Width + 1), Width) = Width + 1,
         "encoder width did not advance at its boundary");
   end loop;

   Assert
     (Arithmetic.Next_Hash_Slot (Arithmetic.Hash_Slot'Last) = Arithmetic.Hash_Slot'First,
      "LZW hash probing did not wrap");
   Assert
     (Arithmetic.Hash_Start (4_095, 255) = 4_094,
      "wrong LZW hash start at the maximum code and suffix");
   Assert
     (Arithmetic.Can_Follow (4_095, 6, 4_096, 4_095)
      and then not Arithmetic.Can_Follow (4_095, 6, 4_095, 4_095)
      and then Arithmetic.Push_Count (4_095) = 4_096,
      "dictionary traversal bounds are wrong");
   Assert
     (Arithmetic.Can_Insert (4_095)
      and then Arithmetic.After_Insert (4_095) = 4_096
      and then not Arithmetic.Can_Insert (4_096),
      "dictionary insertion bounds are wrong");
end Arithmetic_Transitions_Are_Bounded;

