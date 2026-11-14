separate (Giflib.Testing.Test_Container)
procedure Rejects_Dimensions_And_Limits (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Zero_Width : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 0, 0, 1, 0, 0, 0, 0];
   Wide : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 3, 0, 1, 0, 0, 0, 0];
   Tall : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 3, 0, 0, 0, 0];
   Source : Giflib.Streams.Memory_Source (Zero_Width'Access);
   Wide_Source : Giflib.Streams.Memory_Source (Wide'Access);
   Tall_Source : Giflib.Streams.Memory_Source (Tall'Access);
   Header : Giflib.Internal.Container.Header_Info;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Container.Read_Header (Source, Constraints, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions, "zero width was accepted");

   Constraints.Max_Logical_Width := 2;
   Giflib.Streams.Open (Wide_Source);
   Outcome := Giflib.Internal.Container.Read_Header (Wide_Source, Constraints, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded, "width limit was ignored");
   Assert (Outcome.First_Error.Context.Limit = Giflib.Logical_Width_Limit,
           "width failure lost limit context");

   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Logical_Height := 2;
   Giflib.Streams.Open (Tall_Source);
   Outcome := Giflib.Internal.Container.Read_Header (Tall_Source, Constraints, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
           and then Outcome.First_Error.Context.Limit = Giflib.Logical_Height_Limit,
           "height limit was ignored");
end Rejects_Dimensions_And_Limits;
