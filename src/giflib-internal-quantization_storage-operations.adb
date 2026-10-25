with Giflib.Internal.Quantization_Dithering;
with Giflib.Internal.Quantization_Palette;
with Giflib.Internal.Quantization_Pixels;

package body Giflib.Internal.Quantization_Storage.Operations is
   Cache_Probe_Limit : constant := 8;

   function Charge
     (Work : in out Work_Budgets.Meter;
      Amount : Byte_Count) return Boolean
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      return Accepted;
   end Charge;

   function Reset_Histogram
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Boolean
   is
      Histogram : constant Histogram_Ownership.Element_Access :=
        Histogram_Ownership.Value (Object.Histogram_Data);
   begin
      if not Charge (Work, Byte_Count (Histogram.Counts'Length)) then
         return False;
      end if;
      Histogram.Counts := [others => 0];
      Histogram.Occupied_Count := 0;
      return True;
   end Reset_Histogram;

   procedure Add_Histogram_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index)
   is
      Histogram : constant Histogram_Ownership.Element_Access :=
        Histogram_Ownership.Value (Object.Histogram_Data);
      Palette_Bucket : constant Quantization_Palette.Histogram_Index :=
        Quantization_Palette.Histogram_Index (Bucket);
   begin
      if Histogram.Counts (Palette_Bucket) = 0 then
         Histogram.Occupied_Count := Histogram.Occupied_Count + 1;
         Histogram.Occupied (Histogram.Occupied_Count) := Palette_Bucket;
      end if;
      Histogram.Counts (Palette_Bucket) :=
        Histogram.Counts (Palette_Bucket) + 1;
   end Add_Histogram_Sample;

   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result
   is
   begin
      return Quantization_Palette.Build_Median_Cut
        (Histogram_Ownership.Value (Object.Histogram_Data).all,
         Generated_Start, Opaque_Capacity, Work, Output_Palette);
   end Build_Median_Cut;

   function Reset_Nearest_Cache
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Boolean
   is
   begin
      if not Nearest_Cache_Allocated (Object)
        or else not Charge (Work, Byte_Count (Nearest_Cache_Size))
      then
         return False;
      end if;
      Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data).all :=
        [others => (others => <>)];
      return True;
   end Reset_Nearest_Cache;

   function Nearest
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter) return Palette_Index
   is
      Cache : constant Nearest_Cache_Ownership.Element_Access :=
        Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data);
      Best : Natural := First;
      Best_Distance : Natural := Natural'Last;
      Distance : Natural;
      Key : constant Natural := Quantization_Pixels.Color_Key (Color);
      Start : constant Natural :=
        Quantization_Pixels.Cache_Start (Key, Nearest_Cache_Size);
      Slot : Natural := Start;
      Store_Slot : Natural := Start;
      Probe_Count : Natural := 0;
   begin
      for Probe in 0 .. Cache_Probe_Limit - 1 loop
         Probe_Count := Probe_Count + 1;
         Slot := (Start + Probe) mod Nearest_Cache_Size;
         if not Cache (Slot).Used then
            Store_Slot := Slot;
            exit;
         elsif Cache (Slot).Key = Key then
            if not Charge (Work, Byte_Count (Probe_Count)) then
               return Palette_Index (Best);
            end if;
            return Cache (Slot).Value;
         end if;
      end loop;
      if not Charge (Work, Byte_Count (Probe_Count))
        or else not Charge
          (Work, Byte_Count (Output_Palette.Length - First))
      then
         return Palette_Index (Best);
      end if;
      for I in First .. Output_Palette.Length - 1 loop
         if not (Exclude_Index and then Palette_Index (I) = Excluded_Index) then
            Distance := Natural
              (Quantization_Arithmetic.Squared_Distance
                 (Color, Output_Palette.Colors (Palette_Index (I))));
            if Distance < Best_Distance then
               Best := I;
               Best_Distance := Distance;
            end if;
         end if;
      end loop;
      Cache (Store_Slot) :=
        (Used => True, Key => Key, Value => Palette_Index (Best));
      return Palette_Index (Best);
   end Nearest;

   function Reset_Errors
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Boolean
   is
   begin
      if Error_Length (Object) < Required_Length
        or else not Charge (Work, Byte_Count (Required_Length))
      then
         return False;
      end if;
      Error_Ownership.Value (Object.Error_Data).all
        (0 .. Required_Length - 1) := [others => 0];
      return True;
   end Reset_Errors;

   procedure Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) is
   begin
      Quantization_Dithering.Clear_Next_Row
        (Error_Ownership.Value (Object.Error_Data).all, Next_Group, Span);
   end Clear_Next_Row;

   procedure Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) is
   begin
      Quantization_Dithering.Clear_Transparent
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, X, Span);
   end Clear_Transparent;

   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Palettes.RGB_Color
   is
   begin
      return Quantization_Dithering.Adjust
        (Color, Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, X, Span);
   end Adjust;

   procedure Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) is
   begin
      Quantization_Dithering.Diffuse
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, Next_Group, X, Span, Adjusted, Chosen);
   end Diffuse;
end Giflib.Internal.Quantization_Storage.Operations;
