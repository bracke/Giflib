with Ada.Unchecked_Deallocation;

with Giflib.Errors;

package body Giflib.Quantization is
   use type Palettes.RGB_Color;

   subtype Histogram_Index is Natural range 0 .. 32_767;
   type Histogram_Array is array (Histogram_Index) of Natural;
   type Histogram_Access is access Histogram_Array;
   procedure Free_Histogram is new Ada.Unchecked_Deallocation
     (Histogram_Array, Histogram_Access);

   type Error_Array is array (Natural range <>) of Long_Integer;
   type Error_Array_Access is access Error_Array;
   procedure Free_Errors is new Ada.Unchecked_Deallocation
     (Error_Array, Error_Array_Access);

   type Color_Box is record
      R_Min : Natural range 0 .. 31 := 0;
      R_Max : Natural range 0 .. 31 := 31;
      G_Min : Natural range 0 .. 31 := 0;
      G_Max : Natural range 0 .. 31 := 31;
      B_Min : Natural range 0 .. 31 := 0;
      B_Max : Natural range 0 .. 31 := 31;
      Population : Natural := 0;
      Valid : Boolean := False;
   end record;

   type Box_Array is array (Natural range 0 .. 255) of Color_Box;

   type Source_Pixel is record
      Color : Palettes.RGB_Color;
      Alpha : Byte := 255;
   end record;

   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      Pixel_Total : constant Byte_Count := Byte_Count (Source.Width) * Byte_Count (Source.Height);
      Histogram : Histogram_Access := null;
      Errors : Error_Array_Access := null;
      Exact_Colors : Palettes.Color_Array := [others => (others => 0)];
      Exact_Count : Natural := 0;
      Exact_Overflow : Boolean := False;
      Boxes : Box_Array;
      Box_Count : Natural := 0;
      Work : Byte_Count := 0;
      Budget_Failed : Boolean := False;
      Generated_Start : Natural := 0;
      Opaque_Capacity : Natural;

      function Fail
        (Code : Giflib.Errors.Error_Code;
         Context : Giflib.Errors.Diagnostic_Context := (others => <>)) return Results.Result
      is
      begin
         if Histogram /= null then
            Free_Histogram (Histogram);
         end if;
         if Errors /= null then
            Free_Errors (Errors);
         end if;
         return Results.Failure (Giflib.Errors.Make (Code, Context));
      end Fail;

      function Charge (Amount : Byte_Count := 1) return Boolean is
      begin
         if Work > Constraints.Max_Quantization_Work
           or else Amount > Constraints.Max_Quantization_Work - Work
         then
            Budget_Failed := True;
            return False;
         end if;
         Work := Work + Amount;
         return True;
      end Charge;

      function Pixel_At (X, Y : Natural) return Source_Pixel is
         BPP : constant Natural := Images.Bytes_Per_Pixel (Source.Format);
         Offset : constant Byte_Count :=
           Byte_Count (Y) * Byte_Count (Source.Stride) + Byte_Count (X * BPP);
         Position : constant Positive := Source.Data'First + Natural (Offset);
         Result : Source_Pixel;
      begin
         case Source.Format is
            when RGB_24 =>
               Result.Color :=
                 (Source.Data (Position), Source.Data (Position + 1), Source.Data (Position + 2));
            when BGR_24 =>
               Result.Color :=
                 (Source.Data (Position + 2), Source.Data (Position + 1), Source.Data (Position));
            when RGBA_32 =>
               Result.Color :=
                 (Source.Data (Position), Source.Data (Position + 1), Source.Data (Position + 2));
               Result.Alpha := Source.Data (Position + 3);
            when BGRA_32 =>
               Result.Color :=
                 (Source.Data (Position + 2), Source.Data (Position + 1), Source.Data (Position));
               Result.Alpha := Source.Data (Position + 3);
            when Indexed_8 =>
               null;
         end case;
         return Result;
      end Pixel_At;

      function Is_Transparent (Pixel : Source_Pixel) return Boolean is
        (Options.Use_Transparency
         and then Source.Format in RGBA_32 | BGRA_32
         and then Pixel.Alpha <= Options.Alpha_Threshold);

      function Histogram_Of (Color : Palettes.RGB_Color) return Histogram_Index is
        (Natural (Color.Red) / 8 * 1_024
         + Natural (Color.Green) / 8 * 32
         + Natural (Color.Blue) / 8);

      procedure Analyze (Item : in out Color_Box) is
         Bounds : constant Color_Box := Item;
         First : Boolean := True;
         R, G, B : Natural;
         Count : Natural;
         R_Min, R_Max, G_Min, G_Max, B_Min, B_Max : Natural := 0;
      begin
         Item.Population := 0;
         for I in Histogram_Index loop
            exit when Budget_Failed;
            if not Charge then
               exit;
            end if;
            Count := Histogram (I);
            if Count > 0 then
               R := I / 1_024;
               G := I / 32 mod 32;
               B := I mod 32;
               if R in Bounds.R_Min .. Bounds.R_Max
                 and then G in Bounds.G_Min .. Bounds.G_Max
                 and then B in Bounds.B_Min .. Bounds.B_Max
               then
                  if First then
                     R_Min := R;
                     R_Max := R;
                     G_Min := G;
                     G_Max := G;
                     B_Min := B;
                     B_Max := B;
                     First := False;
                  else
                     R_Min := Natural'Min (R_Min, R);
                     R_Max := Natural'Max (R_Max, R);
                     G_Min := Natural'Min (G_Min, G);
                     G_Max := Natural'Max (G_Max, G);
                     B_Min := Natural'Min (B_Min, B);
                     B_Max := Natural'Max (B_Max, B);
                  end if;
                  Item.Population := Item.Population + Count;
               end if;
            end if;
         end loop;
         Item.Valid := not First;
         if Item.Valid then
            Item.R_Min := R_Min;
            Item.R_Max := R_Max;
            Item.G_Min := G_Min;
            Item.G_Max := G_Max;
            Item.B_Min := B_Min;
            Item.B_Max := B_Max;
         end if;
      end Analyze;

      procedure Split_Box (Index : Natural) is
         type Axis_Counts is array (Natural range 0 .. 31) of Natural;
         Counts : Axis_Counts := [others => 0];
         Original : constant Color_Box := Boxes (Index);
         Axis : Natural;
         Goal : constant Natural := (Original.Population + 1) / 2;
         Running : Natural := 0;
         Split : Natural := 0;
         R, G, B, Position : Natural;
         Left, Right : Color_Box := Original;
      begin
         if Original.R_Max - Original.R_Min >= Original.G_Max - Original.G_Min
           and then Original.R_Max - Original.R_Min >= Original.B_Max - Original.B_Min
         then
            Axis := 0;
         elsif Original.G_Max - Original.G_Min >= Original.B_Max - Original.B_Min then
            Axis := 1;
         else
            Axis := 2;
         end if;
         for I in Histogram_Index loop
            exit when Budget_Failed;
            if not Charge then
               exit;
            end if;
            if Histogram (I) > 0 then
               R := I / 1_024;
               G := I / 32 mod 32;
               B := I mod 32;
               if R in Original.R_Min .. Original.R_Max
                 and then G in Original.G_Min .. Original.G_Max
                 and then B in Original.B_Min .. Original.B_Max
               then
                  Position := (case Axis is when 0 => R, when 1 => G, when others => B);
                  Counts (Position) := Counts (Position) + Histogram (I);
               end if;
            end if;
         end loop;
         if Budget_Failed then
            return;
         end if;
         declare
            Minimum : constant Natural :=
              (case Axis is
                  when 0 => Original.R_Min,
                  when 1 => Original.G_Min,
                  when others => Original.B_Min);
            Maximum : constant Natural :=
              (case Axis is
                  when 0 => Original.R_Max,
                  when 1 => Original.G_Max,
                  when others => Original.B_Max);
         begin
            Split := Minimum;
            for Value in Minimum .. Maximum - 1 loop
               Running := Running + Counts (Value);
               Split := Value;
               exit when Running >= Goal;
            end loop;
         end;
         case Axis is
            when 0 => Left.R_Max := Split; Right.R_Min := Split + 1;
            when 1 => Left.G_Max := Split; Right.G_Min := Split + 1;
            when others => Left.B_Max := Split; Right.B_Min := Split + 1;
         end case;
         Analyze (Left);
         Analyze (Right);
         if Left.Valid and then Right.Valid and then not Budget_Failed then
            Boxes (Index) := Left;
            Boxes (Box_Count) := Right;
            Box_Count := Box_Count + 1;
         end if;
      end Split_Box;

      function Representative (Item : Color_Box) return Palettes.RGB_Color is
         R_Sum, G_Sum, B_Sum, Total : Byte_Count := 0;
         R, G, B : Natural;
         Count : Natural;
      begin
         for I in Histogram_Index loop
            exit when Budget_Failed;
            if not Charge then
               exit;
            end if;
            Count := Histogram (I);
            if Count > 0 then
               R := I / 1_024;
               G := I / 32 mod 32;
               B := I mod 32;
               if R in Item.R_Min .. Item.R_Max
                 and then G in Item.G_Min .. Item.G_Max
                 and then B in Item.B_Min .. Item.B_Max
               then
                  R_Sum := R_Sum + Byte_Count (R * 255 / 31) * Byte_Count (Count);
                  G_Sum := G_Sum + Byte_Count (G * 255 / 31) * Byte_Count (Count);
                  B_Sum := B_Sum + Byte_Count (B * 255 / 31) * Byte_Count (Count);
                  Total := Total + Byte_Count (Count);
               end if;
            end if;
         end loop;
         if Total = 0 then
            return (others => 0);
         end if;
         return (Byte (R_Sum / Total), Byte (G_Sum / Total), Byte (B_Sum / Total));
      end Representative;

      function Clamp (Value : Long_Integer) return Byte is
        (if Value < 0 then 0 elsif Value > 255 then 255 else Byte (Value));

      function Nearest (Color : Palettes.RGB_Color) return Palette_Index is
         First : constant Natural := Generated_Start;
         Best : Natural := First;
         Best_Distance : Natural := Natural'Last;
         Distance : Natural;
         DR, DG, DB : Integer;
      begin
         for I in First .. Output_Palette.Length - 1 loop
            if not Charge then
               return Palette_Index (Best);
            end if;
            if not (Has_Transparency
                    and then Options.Strategy = Use_Fixed_Palette
                    and then Palette_Index (I) = Transparent_Index)
            then
               DR := Integer (Color.Red) - Integer (Output_Palette.Colors (Palette_Index (I)).Red);
               DG := Integer (Color.Green) - Integer (Output_Palette.Colors (Palette_Index (I)).Green);
               DB := Integer (Color.Blue) - Integer (Output_Palette.Colors (Palette_Index (I)).Blue);
               Distance := Natural (DR * DR + DG * DG + DB * DB);
               if Distance < Best_Distance then
                  Best := I;
                  Best_Distance := Distance;
               end if;
            end if;
         end loop;
         return Palette_Index (Best);
      end Nearest;

      Outcome : Results.Result;
      Pixel : Source_Pixel;
      Found : Boolean;
      Allocation : Byte_Count;
      Index : Natural;
   begin
      Output_Palette := (others => <>);
      Has_Transparency := False;
      Transparent_Index := 0;
      Outcome := Images.Validate (Source);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Source.Format = Indexed_8 then
         return Results.Failure (Giflib.Errors.Make (Giflib.Errors.Unsupported_Feature));
      elsif Byte_Count (Indexed_Pixels'Length) /= Pixel_Total then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Invalid_Dimensions,
               (Expected => Pixel_Total, Actual => Byte_Count (Indexed_Pixels'Length), others => <>)));
      elsif Pixel_Total > Byte_Count (Constraints.Max_Frame_Pixels) then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Byte_Count (Constraints.Max_Frame_Pixels), Actual => Pixel_Total,
                Limit => Frame_Pixel_Limit, others => <>)));
      end if;

      Allocation := Byte_Count (Histogram_Array'Size / 8);
      if Allocation > Constraints.Max_Allocation_Bytes then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Constraints.Max_Allocation_Bytes, Actual => Allocation,
                Limit => Allocation_Byte_Limit, others => <>)));
      end if;
      Histogram := new Histogram_Array'[others => 0];

      for Y in 0 .. Natural (Source.Height) - 1 loop
         for X in 0 .. Natural (Source.Width) - 1 loop
            if not Charge then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  (Expected => Constraints.Max_Quantization_Work, Actual => Work + 1,
                   Limit => Quantization_Work_Limit, others => <>));
            end if;
            Pixel := Pixel_At (X, Y);
            if Is_Transparent (Pixel) then
               Has_Transparency := True;
            else
               Histogram (Histogram_Of (Pixel.Color)) := Histogram (Histogram_Of (Pixel.Color)) + 1;
               Found := False;
               for I in 0 .. Exact_Count - 1 loop
                  if Exact_Colors (Palette_Index (I)) = Pixel.Color then
                     Found := True;
                     exit;
                  end if;
               end loop;
               if not Found and then Exact_Count < 256 then
                  Exact_Colors (Palette_Index (Exact_Count)) := Pixel.Color;
                  Exact_Count := Exact_Count + 1;
               elsif not Found then
                  Exact_Overflow := True;
               end if;
            end if;
         end loop;
      end loop;

      if Options.Strategy = Use_Fixed_Palette then
         if Options.Fixed_Palette.Length < 2 then
            return Fail (Giflib.Errors.Missing_Color_Table);
         elsif Has_Transparency
           and then not Palettes.Contains (Options.Fixed_Palette, Options.Fixed_Transparent_Index)
         then
            return Fail (Giflib.Errors.Palette_Index_Out_Of_Range);
         end if;
         Output_Palette := Options.Fixed_Palette;
         Transparent_Index := Options.Fixed_Transparent_Index;
         Generated_Start := 0;
      else
         if Has_Transparency then
            Transparent_Index := 0;
            Generated_Start := 1;
            Output_Palette.Colors (0) := (others => 0);
         else
            Generated_Start := 0;
         end if;
         Opaque_Capacity := Options.Maximum_Colors - Generated_Start;
         if not Exact_Overflow and then Exact_Count <= Opaque_Capacity then
            for I in 0 .. Exact_Count - 1 loop
               Output_Palette.Colors (Palette_Index (Generated_Start + I)) :=
                 Exact_Colors (Palette_Index (I));
            end loop;
            Output_Palette.Length := Generated_Start + Exact_Count;
         else
            Boxes (0) := (others => <>);
            Analyze (Boxes (0));
            if Budget_Failed then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  (Expected => Constraints.Max_Quantization_Work, Actual => Work + 1,
                   Limit => Quantization_Work_Limit, others => <>));
            end if;
            Box_Count := (if Boxes (0).Valid then 1 else 0);
            while Box_Count < Opaque_Capacity loop
               declare
                  Choice : Natural := Box_Count;
                  Best_Range : Natural := 0;
                  Spread : Natural;
               begin
                  for I in 0 .. Box_Count - 1 loop
                     Spread := Natural'Max
                       (Boxes (I).R_Max - Boxes (I).R_Min,
                        Natural'Max (Boxes (I).G_Max - Boxes (I).G_Min,
                                     Boxes (I).B_Max - Boxes (I).B_Min));
                     if Spread > Best_Range then
                        Best_Range := Spread;
                        Choice := I;
                     end if;
                  end loop;
                  exit when Choice = Box_Count or else Best_Range = 0;
                  Split_Box (Choice);
                  exit when Budget_Failed;
               end;
            end loop;
            if Budget_Failed then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  (Expected => Constraints.Max_Quantization_Work, Actual => Work + 1,
                   Limit => Quantization_Work_Limit, others => <>));
            end if;
            for I in 0 .. Box_Count - 1 loop
               Output_Palette.Colors (Palette_Index (Generated_Start + I)) := Representative (Boxes (I));
            end loop;
            if Budget_Failed then
               return Fail
                 (Giflib.Errors.Limit_Exceeded,
                  (Expected => Constraints.Max_Quantization_Work, Actual => Work + 1,
                   Limit => Quantization_Work_Limit, others => <>));
            end if;
            Output_Palette.Length := Generated_Start + Box_Count;
         end if;
         if Output_Palette.Length < 2 then
            Output_Palette.Length := 2;
            Output_Palette.Colors (Palette_Index (1)) := Output_Palette.Colors (Palette_Index (0));
         end if;
      end if;

      if Has_Transparency and then Options.Strategy = Use_Fixed_Palette then
         Generated_Start := 0;
      elsif Has_Transparency then
         Generated_Start := 1;
      else
         Generated_Start := 0;
      end if;

      if Options.Dither = Floyd_Steinberg then
         Allocation := Byte_Count (6 * (Natural (Source.Width) + 2)) * Byte_Count (Long_Integer'Size / 8);
         if Allocation > Constraints.Max_Allocation_Bytes - Byte_Count (Histogram_Array'Size / 8) then
            return Fail
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Constraints.Max_Allocation_Bytes,
                Actual => Allocation + Byte_Count (Histogram_Array'Size / 8),
                Limit => Allocation_Byte_Limit, others => <>));
         end if;
         Errors := new Error_Array (0 .. 6 * (Natural (Source.Width) + 2) - 1);
         Errors.all := [others => 0];
      end if;

      Index := Indexed_Pixels'First;
      for Y in 0 .. Natural (Source.Height) - 1 loop
         declare
            Span : constant Natural := Natural (Source.Width) + 2;
            Current_Group : constant Natural := (if Y mod 2 = 0 then 0 else 3);
            Next_Group : constant Natural := (if Y mod 2 = 0 then 3 else 0);
         begin
            if Errors /= null then
               for Channel in 0 .. 2 loop
                  for X in 0 .. Span - 1 loop
                     Errors (Next_Group * Span + Channel * Span + X) := 0;
                  end loop;
               end loop;
            end if;
            for X in 0 .. Natural (Source.Width) - 1 loop
               Pixel := Pixel_At (X, Y);
               if Is_Transparent (Pixel) then
                  Indexed_Pixels (Index) := Byte (Transparent_Index);
                  if Errors /= null then
                     for Channel in 0 .. 2 loop
                        Errors (Current_Group * Span + Channel * Span + X + 1) := 0;
                     end loop;
                  end if;
               else
                  declare
                     Adjusted : Palettes.RGB_Color := Pixel.Color;
                     Chosen : Palette_Index;
                  begin
                     if Errors /= null then
                        Adjusted :=
                          (Clamp (Long_Integer (Pixel.Color.Red)
                                  + Errors (Current_Group * Span + X + 1) / 16),
                           Clamp (Long_Integer (Pixel.Color.Green)
                                  + Errors (Current_Group * Span + Span + X + 1) / 16),
                           Clamp (Long_Integer (Pixel.Color.Blue)
                                  + Errors (Current_Group * Span + 2 * Span + X + 1) / 16));
                     end if;
                     Chosen := Nearest (Adjusted);
                     if Budget_Failed then
                        return Fail
                          (Giflib.Errors.Limit_Exceeded,
                           (Expected => Constraints.Max_Quantization_Work, Actual => Work + 1,
                            Limit => Quantization_Work_Limit, others => <>));
                     end if;
                     Indexed_Pixels (Index) := Byte (Chosen);
                     if Errors /= null then
                        declare
                           Chosen_Color : constant Palettes.RGB_Color := Output_Palette.Colors (Chosen);
                           Error_Delta : constant array (Natural range 0 .. 2) of Long_Integer :=
                             [Long_Integer (Adjusted.Red) - Long_Integer (Chosen_Color.Red),
                              Long_Integer (Adjusted.Green) - Long_Integer (Chosen_Color.Green),
                              Long_Integer (Adjusted.Blue) - Long_Integer (Chosen_Color.Blue)];
                        begin
                           for Channel in 0 .. 2 loop
                              Errors (Current_Group * Span + Channel * Span + X + 2) :=
                                Errors (Current_Group * Span + Channel * Span + X + 2)
                                + Error_Delta (Channel) * 7;
                              Errors (Next_Group * Span + Channel * Span + X) :=
                                Errors (Next_Group * Span + Channel * Span + X)
                                + Error_Delta (Channel) * 3;
                              Errors (Next_Group * Span + Channel * Span + X + 1) :=
                                Errors (Next_Group * Span + Channel * Span + X + 1)
                                + Error_Delta (Channel) * 5;
                              Errors (Next_Group * Span + Channel * Span + X + 2) :=
                                Errors (Next_Group * Span + Channel * Span + X + 2)
                                + Error_Delta (Channel);
                           end loop;
                        end;
                     end if;
                  end;
               end if;
               Index := Index + 1;
            end loop;
         end;
      end loop;

      Free_Histogram (Histogram);
      if Errors /= null then
         Free_Errors (Errors);
      end if;
      return Results.Success;
   exception
      when Storage_Error =>
         return Fail
           (Giflib.Errors.Limit_Exceeded,
            (Expected => Constraints.Max_Allocation_Bytes,
             Limit => Allocation_Byte_Limit, others => <>));
   end Quantize;
end Giflib.Quantization;
