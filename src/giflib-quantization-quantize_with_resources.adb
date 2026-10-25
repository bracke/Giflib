separate (Giflib.Quantization)
function Quantize_With_Resources
  (Context : in out Workspace;
   Source : Images.Image_View;
   Indexed_Pixels : out Streams.Byte_Array;
   Output : out Quantization_Result;
   Options : Quantize_Options;
   Constraints : Limits.Limit_Set) return Results.Result
is
   Pixel_Total : constant Byte_Count :=
     Internal.Geometry_Arithmetic.Area (Source.Width, Source.Height);
   Work : Work_Tracker (Constraints.Max_Quantization_Work);
   Prepared : Palette_Phase.Prepared_Palette;
   Outcome : Results.Result;
begin
   Outcome := Validate_Request
     (Context,
      Source,
      Indexed_Pixels'Length,
      Options,
      Constraints,
      Pixel_Total);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Palette_Phase.Build
     (Context, Source, Options, Constraints, Work, Prepared);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Outcome := Mapping_Phase.Map
     (Context,
      Source,
      Indexed_Pixels,
      Prepared,
      Options,
      Constraints,
      Work);
   if not Results.Succeeded (Outcome) then
      return Outcome;
   end if;

   Output :=
     (Palette => Prepared.Value,
      Transparency =>
        (if Prepared.Has_Transparency
         then (Present => True, Index => Prepared.Transparent_Index)
         else (Present => False)));
   return Results.Success;
end Quantize_With_Resources;
