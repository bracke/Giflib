separate (Giflib.Testing.Test_Streams)
procedure Memory_Source_Handles_Short_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : aliased constant Giflib.Streams.Byte_Array := [10, 20, 30, 40, 50];
   Target : Giflib.Streams.Byte_Array (1 .. 5) := [others => 0];
   Direct : Giflib.Streams.Byte_Array (1 .. 3) := [others => 0];
   Large_Input : aliased Giflib.Streams.Byte_Array := [1 .. 2_048 => 0];
   Large_Target : Giflib.Streams.Byte_Array (1 .. 2_048) := [others => 0];
   Source : Giflib.Streams.Memory_Source (Input'Access);
   Large_Source : Giflib.Streams.Memory_Source (Large_Input'Access);
   Step : Giflib.Streams.Source_Result;
   Outcome : Giflib.Results.Result;
begin
   for I in Large_Input'Range loop
      Large_Input (I) := Giflib.Byte (I mod 251);
   end loop;
   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Step := Source.Read (Direct);
   Assert (Step.Count = 2 and then Direct (1 .. 2) = Input (1 .. 2), "short read returned wrong bytes");
   Assert (Source.Offset = 2 and then not Step.End_Of_Input, "short read returned wrong state");

   Giflib.Streams.Open (Source, Max_Transfer => 2);
   Outcome := Giflib.Streams.Read_Exact (Source, Target);
   Assert (Giflib.Results.Succeeded (Outcome), "exact read rejected valid short reads");
   Assert (Target = Input, "exact read changed bytes");
   Assert (Source.Offset = 5, "exact read offset is wrong");
   Step := Source.Read (Direct);
   Assert (Step.Count = 0 and then Step.End_Of_Input, "EOF was not reported deterministically");

   Giflib.Streams.Open (Large_Source);
   Outcome := Giflib.Streams.Read_Exact (Large_Source, Large_Target);
   Assert
     (Giflib.Results.Succeeded (Outcome) and then Large_Target = Large_Input,
      "bulk memory-source read changed bytes");
end Memory_Source_Handles_Short_Reads;

