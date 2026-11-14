separate (Giflib.Testing.Test_Container)
procedure Accepts_Geometry_Boundaries
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   type Dimension_Array is array (Positive range <>) of Natural;
   Dimensions : constant Dimension_Array := [255, 256, 257];
   Header : Giflib.Internal.Container.Header_Info;
   Outcome : Giflib.Results.Result;

   function Fixture (Width, Height : Natural) return Giflib.Streams.Byte_Array is
   begin
      return
        [71, 73, 70, 56, 57, 97,
         Giflib.Byte (Width mod 256), Giflib.Byte (Width / 256),
         Giflib.Byte (Height mod 256), Giflib.Byte (Height / 256),
         0, 0, 0];
   end Fixture;
begin
   for Dimension of Dimensions loop
      declare
         Wide : aliased constant Giflib.Streams.Byte_Array :=
           Fixture (Dimension, 1);
         Tall : aliased constant Giflib.Streams.Byte_Array :=
           Fixture (1, Dimension);
         Wide_Source : Giflib.Streams.Memory_Source (Wide'Access);
         Tall_Source : Giflib.Streams.Memory_Source (Tall'Access);
      begin
         Giflib.Streams.Open (Wide_Source);
         Outcome := Giflib.Internal.Container.Read_Header
           (Wide_Source, Giflib.Limits.Default_Limits, Header);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Natural (Header.Width) = Dimension
                 and then Header.Height = 1,
                 "width boundary was rejected or changed");

         Giflib.Streams.Open (Tall_Source);
         Outcome := Giflib.Internal.Container.Read_Header
           (Tall_Source, Giflib.Limits.Default_Limits, Header);
         Assert (Giflib.Results.Succeeded (Outcome)
                 and then Header.Width = 1
                 and then Natural (Header.Height) = Dimension,
                 "height boundary was rejected or changed");
      end;
   end loop;
end Accepts_Geometry_Boundaries;
