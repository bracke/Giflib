separate (Giflib.Testing.Test_Streams)
procedure Fixed_Destination_Handles_Short_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Input : constant Giflib.Streams.Byte_Array := [7, 8, 9, 10, 11];
   Storage : aliased Giflib.Streams.Byte_Array := [0, 0, 0, 0, 0];
   Destination : Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Outcome : Giflib.Results.Result;
   Flush_Error : Giflib.Errors.Error;
begin
   Giflib.Streams.Open (Destination, Max_Transfer => 2);
   Outcome := Giflib.Streams.Write_All (Destination, Input);
   Assert (Giflib.Results.Succeeded (Outcome), "write-all rejected valid short writes");
   Assert (Storage = Input, "write-all changed bytes");
   Assert (Destination.Offset = 5, "destination offset is wrong");
   Flush_Error := Destination.Flush;
   Assert (not Giflib.Errors.Is_Fatal (Flush_Error), "fixed destination flush failed");
end Fixed_Destination_Handles_Short_Writes;

