separate (Giflib.Testing.Test_Streams)
procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [7, 8, 9, 10, 11];
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0];
   Large_Input : Giflib.Streams.Byte_Array (1 .. 2_048) := [others => 0];
   Large_Storage : aliased Giflib.Streams.Byte_Array := [1 .. 2_048 => 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Large_Destination : Giflib.Streams.Fixed_Buffer_Destination
     (Large_Storage'Access);
   Outcome : Giflib.Results.Result;
   Flush_Error : Giflib.Errors.Error;
begin
   for I in Large_Input'Range loop
      Large_Input (I) := Giflib.Byte (I mod 251);
   end loop;
   Giflib.Streams.Open (Destination, Max_Transfer => 2);
   Outcome := Giflib.Streams.Write_All (Destination, Input);
   Assert (Giflib.Results.Succeeded (Outcome), "write-all rejected valid short writes");
   Assert (Storage = Input, "write-all changed bytes");
   Assert (Destination.Offset = 5, "destination offset is wrong");
   Flush_Error := Destination.Flush;
   Assert (not Giflib.Errors.Is_Fatal (Flush_Error), "fixed destination flush failed");

   Giflib.Streams.Open (Large_Destination);
   Outcome := Giflib.Streams.Write_All (Large_Destination, Large_Input);
   Assert
     (Giflib.Results.Succeeded (Outcome)
        and then Large_Storage = Large_Input,
      "bulk fixed-destination write changed bytes");
end Fixed_Destination_Handles_Short_Writes;

