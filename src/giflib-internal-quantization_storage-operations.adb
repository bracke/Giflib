with Giflib.Internal.Quantization_Dithering;
with Giflib.Internal.Quantization_Palette;
with Giflib.Errors;

package body Giflib.Internal.Quantization_Storage.Operations is
   Cache_Probe_Limit : constant := 8;
   Cache_Key_Last : constant := 16#FF_FF_FF#;

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
      Work : in out Work_Budgets.Meter) return Operation_Status
   is
   begin
      if not Histogram_Allocated (Object) then
         return Operation_Invariant_Failure;
      end if;
      declare
         Histogram : constant Histogram_Ownership.Element_Access :=
           Histogram_Ownership.Value (Object.Histogram_Data);
      begin
         if not Charge (Work, Byte_Count (Histogram.Counts'Length)) then
            return Operation_Work_Limit;
         end if;
         Histogram.Counts := [others => 0];
         Histogram.Occupied_Count := 0;
      end;
      return Operation_Ready;
   end Reset_Histogram;

   function Add_Histogram_Sample
     (Object : in out Resources;
      Bucket : Histogram_Index) return Operation_Status
   is
      Palette_Bucket : constant Quantization_Palette.Histogram_Index :=
        Quantization_Palette.Histogram_Index (Bucket);
   begin
      if not Histogram_Allocated (Object) then
         return Operation_Invariant_Failure;
      end if;
      declare
         Histogram : constant Histogram_Ownership.Element_Access :=
           Histogram_Ownership.Value (Object.Histogram_Data);
      begin
         if Histogram.Counts (Palette_Bucket) = 0 then
            if Histogram.Occupied_Count = Histogram.Occupied'Length then
               return Operation_Invariant_Failure;
            end if;
            Histogram.Occupied_Count := Histogram.Occupied_Count + 1;
            Histogram.Occupied (Histogram.Occupied_Count) := Palette_Bucket;
         end if;
         if Histogram.Counts (Palette_Bucket) = Natural'Last then
            return Operation_Invariant_Failure;
         end if;
         Histogram.Counts (Palette_Bucket) :=
           Histogram.Counts (Palette_Bucket) + 1;
      end;
      return Operation_Ready;
   end Add_Histogram_Sample;

   function Build_Median_Cut
     (Object : in out Resources;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work : in out Work_Budgets.Meter;
      Output_Palette : in out Palettes.Palette) return Results.Result
   is
   begin
      if not Histogram_Allocated (Object) then
         return Results.Failure
           (Giflib.Errors.Make (Giflib.Errors.Internal_Invariant_Failed));
      end if;
      return Quantization_Palette.Build_Median_Cut
        (Histogram_Ownership.Value (Object.Histogram_Data).all,
         Generated_Start, Opaque_Capacity, Work, Output_Palette);
   end Build_Median_Cut;

   function Reset_Nearest_Cache
     (Object : in out Resources;
      Work : in out Work_Budgets.Meter) return Operation_Status
   is
   begin
      if not Nearest_Cache_Allocated (Object)
        or else not Charge (Work, Byte_Count (Cache_Capacity))
      then
         return (if Nearest_Cache_Allocated (Object)
                 then Operation_Work_Limit
                 else Operation_Invariant_Failure);
      end if;
      Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data).all :=
        [others => (others => <>)];
      return Operation_Ready;
   end Reset_Nearest_Cache;

   function Probe_Nearest_Cache
     (Object : in out Resources;
      Key : Natural;
      Start : Natural) return Cache_Probe_Result
   is
      Slot : Natural;
      Probe_Count : Natural := 0;
   begin
      if not Nearest_Cache_Allocated (Object)
        or else Key > Cache_Key_Last
        or else Start >= Cache_Capacity
      then
         return (others => <>);
      end if;
      declare
         Cache : constant Nearest_Cache_Ownership.Element_Access :=
           Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data);
      begin
         for Probe in 0 .. Cache_Probe_Limit - 1 loop
            Probe_Count := Probe_Count + 1;
            Slot := (Start + Probe) mod Cache_Capacity;
            if not Cache (Slot).Used then
               return (Status => Operation_Ready, Found => False,
                       Value => 0, Store_Slot => Slot,
                       Probe_Count => Probe_Count);
            elsif Cache (Slot).Key = Key then
               return (Status => Operation_Ready, Found => True,
                       Value => Cache (Slot).Value, Store_Slot => Slot,
                       Probe_Count => Probe_Count);
            end if;
         end loop;
      end;
      return (Status => Operation_Ready, Found => False, Value => 0,
              Store_Slot => Start, Probe_Count => Probe_Count);
   end Probe_Nearest_Cache;

   function Store_Nearest_Cache
     (Object : in out Resources;
      Slot : Natural;
      Key : Natural;
      Value : Palette_Index) return Operation_Status is
   begin
      if not Nearest_Cache_Allocated (Object)
        or else Slot >= Cache_Capacity
        or else Key > Cache_Key_Last
      then
         return Operation_Invariant_Failure;
      end if;
      Nearest_Cache_Ownership.Value (Object.Nearest_Cache_Data).all (Slot) :=
        (Used => True, Key => Key, Value => Value);
      return Operation_Ready;
   end Store_Nearest_Cache;

   function Reset_Errors
     (Object : in out Resources;
      Required_Length : Positive;
      Work : in out Work_Budgets.Meter) return Operation_Status
   is
   begin
      if Error_Length (Object) < Required_Length
        or else not Charge (Work, Byte_Count (Required_Length))
      then
         return (if Error_Length (Object) >= Required_Length
                 then Operation_Work_Limit
                 else Operation_Invariant_Failure);
      end if;
      Error_Ownership.Value (Object.Error_Data).all
        (0 .. Required_Length - 1) := [others => 0];
      return Operation_Ready;
   end Reset_Errors;

   function Clear_Next_Row
     (Object : in out Resources;
      Next_Group : Group_Index;
      Span : Error_Span) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6 then
         return Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Clear_Next_Row
        (Error_Ownership.Value (Object.Error_Data).all, Next_Group, Span);
      return Operation_Ready;
   end Clear_Next_Row;

   function Clear_Transparent
     (Object : in out Resources;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Clear_Transparent
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, X, Span);
      return Operation_Ready;
   end Clear_Transparent;

   function Adjust
     (Object : in out Resources;
      Color : Palettes.RGB_Color;
      Current_Group : Group_Index;
      X : Natural;
      Span : Error_Span) return Color_Outcome
   is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 1
      then
         return (Status => Operation_Invariant_Failure, Value => Color);
      end if;
      return
        (Status => Operation_Ready,
         Value => Quantization_Dithering.Adjust
           (Color, Error_Ownership.Value (Object.Error_Data).all,
            Current_Group, X, Span));
   end Adjust;

   function Diffuse
     (Object : in out Resources;
      Current_Group : Group_Index;
      Next_Group : Group_Index;
      X : Natural;
      Span : Error_Span;
      Adjusted : Palettes.RGB_Color;
      Chosen : Palettes.RGB_Color) return Operation_Status is
   begin
      if Error_Length (Object) < Natural (Span) * 6
        or else X >= Natural (Span) - 2
      then
         return Operation_Invariant_Failure;
      end if;
      Quantization_Dithering.Diffuse
        (Error_Ownership.Value (Object.Error_Data).all,
         Current_Group, Next_Group, X, Span, Adjusted, Chosen);
      return Operation_Ready;
   end Diffuse;
end Giflib.Internal.Quantization_Storage.Operations;
