with Giflib.Internal.Descriptor_Arithmetic;
with Giflib.Internal.Wire_Format;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Internal.Container is
   use type Streams.Byte_Array;

   function Truncated
     (Outcome : Results.Result;
      Object : Streams.Source'Class;
      Block : Block_Kind) return Results.Result;

   function Read_Color_Table
     (Object : in out Streams.Source'Class;
      Length : Positive;
      Block : Block_Kind;
      Palette : out Palettes.Palette) return Results.Result
   is
      Raw : Streams.Byte_Array (1 .. Length * 3);
      Outcome : Results.Result;
   begin
      Palette := (others => <>);
      Outcome := Streams.Read_Exact (Object, Raw);
      if not Results.Succeeded (Outcome) then
         return Truncated (Outcome, Object, Block);
      end if;
      Palette.Length := Length;
      for I in 0 .. Length - 1 loop
         Palette.Colors (Palette_Index (I)) :=
           (Red => Raw (Raw'First + I * 3),
            Green => Raw (Raw'First + I * 3 + 1),
            Blue => Raw (Raw'First + I * 3 + 2));
      end loop;
      return Results.Success;
   end Read_Color_Table;

   function Truncated
     (Outcome : Results.Result;
      Object : Streams.Source'Class;
      Block : Block_Kind) return Results.Result
   is
      use type Errors.Error_Code;
      Item : Errors.Error := Outcome.First_Error;
   begin
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         Item.Code := Errors.Truncated_Block;
         Item.Context.Block := Block;
         Item.Context := Diagnostics.At_Source (Object, Item.Context);
         return Results.Failure (Item);
      end if;
      return Outcome;
   end Truncated;

   function Read_Header
     (Object : in out Streams.Source'Class;
      Constraints : Limits.Limit_Set;
      Header : out Header_Info) return Results.Result is separate;

   function Read_Image_Descriptor
     (Object : in out Streams.Source'Class;
      Header : Header_Info;
      Constraints : Limits.Limit_Set;
      Descriptor : out Image_Descriptor;
      Effective_Palette : out Palettes.Palette;
      Strictness : Strictness_Mode := Strict;
      Separator_Already_Read : Boolean := False) return Results.Result
     is separate;
end Giflib.Internal.Container;
