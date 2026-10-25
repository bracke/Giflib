with Giflib.Errors;
with Giflib.Internal.Resource_Diagnostics;
with Giflib.Internal.Quantization_Arithmetic;

package body Giflib.Internal.Quantization_Palette is
   package Arithmetic renames Giflib.Internal.Quantization_Arithmetic;

   type Color_Box is record
      R_Min : Natural range 0 .. 31 := 0;
      R_Max : Natural range 0 .. 31 := 31;
      G_Min : Natural range 0 .. 31 := 0;
      G_Max : Natural range 0 .. 31 := 31;
      B_Min : Natural range 0 .. 31 := 0;
      B_Max : Natural range 0 .. 31 := 31;
      Population : Natural := 0;
      First : Natural range 0 .. Occupied_Position'Last := 0;
      Last : Natural range 0 .. Occupied_Position'Last := 0;
      Valid : Boolean := False;
   end record;

   type Box_Array is array (Natural range 0 .. 255) of Color_Box;

   function Build_Median_Cut
     (Histogram       : in out Histogram_State;
      Generated_Start : Natural;
      Opaque_Capacity : Natural;
      Work            : in out Work_Budgets.Meter;
      Output_Palette  : in out Palettes.Palette) return Results.Result
   is
      Boxes : Box_Array;
      Box_Count : Natural := 0;
      function Charge (Amount : Byte_Count := 1) return Boolean is
         Accepted : Boolean;
      begin
         Work_Budgets.Try_Charge (Work, Amount, Accepted);
         return Accepted;
      end Charge;

      function Axis_Value
        (Bucket : Histogram_Index;
         Axis   : Natural) return Natural
      is
      begin
         case Axis is
            when 0 => return Arithmetic.Red_Bucket (Bucket);
            when 1 => return Arithmetic.Green_Bucket (Bucket);
            when others => return Arithmetic.Blue_Bucket (Bucket);
         end case;
      end Axis_Value;

      procedure Analyze (Item : in out Color_Box) is
         First : Boolean := True;
         Bucket : Histogram_Index;
         R, G, B : Natural;
         Count : Natural;
         R_Min, R_Max, G_Min, G_Max, B_Min, B_Max : Natural := 0;
      begin
         Item.Population := 0;
         for Position in Item.First .. Item.Last loop
            exit when Work_Budgets.Failed (Work);
            if not Charge then
               exit;
            end if;
            Bucket := Histogram.Occupied (Position);
            Count := Histogram.Counts (Bucket);
            R := Arithmetic.Red_Bucket (Bucket);
            G := Arithmetic.Green_Bucket (Bucket);
            B := Arithmetic.Blue_Bucket (Bucket);
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
         Position : Natural;
         Bucket, Temporary : Histogram_Index;
         Left_Position : Integer;
         Right_Position : Integer;
         Left, Right : Color_Box := Original;
      begin
         if Original.R_Max - Original.R_Min
              >= Original.G_Max - Original.G_Min
           and then Original.R_Max - Original.R_Min
              >= Original.B_Max - Original.B_Min
         then
            Axis := 0;
         elsif Original.G_Max - Original.G_Min
           >= Original.B_Max - Original.B_Min
         then
            Axis := 1;
         else
            Axis := 2;
         end if;
         for Bucket_Position in Original.First .. Original.Last loop
            exit when Work_Budgets.Failed (Work);
            if not Charge then
               exit;
            end if;
            Bucket := Histogram.Occupied (Bucket_Position);
            Position := Axis_Value (Bucket, Axis);
            Counts (Position) := Counts (Position) + Histogram.Counts (Bucket);
         end loop;
         if Work_Budgets.Failed (Work) then
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
         Left_Position := Integer (Original.First);
         Right_Position := Integer (Original.Last);
         loop
            while Left_Position <= Integer (Original.Last) loop
               if not Charge then
                  return;
               end if;
               exit when Axis_Value
                 (Histogram.Occupied (Occupied_Position (Left_Position)), Axis)
                   > Split;
               Left_Position := Left_Position + 1;
            end loop;
            while Right_Position >= Integer (Original.First) loop
               if not Charge then
                  return;
               end if;
               exit when Axis_Value
                 (Histogram.Occupied (Occupied_Position (Right_Position)), Axis)
                   <= Split;
               Right_Position := Right_Position - 1;
            end loop;
            exit when Left_Position > Right_Position;
            Temporary := Histogram.Occupied (Occupied_Position (Left_Position));
            Histogram.Occupied (Occupied_Position (Left_Position)) :=
              Histogram.Occupied (Occupied_Position (Right_Position));
            Histogram.Occupied (Occupied_Position (Right_Position)) := Temporary;
            Left_Position := Left_Position + 1;
            Right_Position := Right_Position - 1;
         end loop;
         if Right_Position < Integer (Original.First)
           or else Left_Position > Integer (Original.Last)
         then
            return;
         end if;
         Left.Last := Natural (Right_Position);
         Right.First := Natural (Left_Position);
         Analyze (Left);
         Analyze (Right);
         if Left.Valid
           and then Right.Valid
           and then not Work_Budgets.Failed (Work)
         then
            Boxes (Index) := Left;
            Boxes (Box_Count) := Right;
            Box_Count := Box_Count + 1;
         end if;
      end Split_Box;

      function Representative (Item : Color_Box) return Palettes.RGB_Color is
         R_Sum, G_Sum, B_Sum, Total : Byte_Count := 0;
         Bucket : Histogram_Index;
         R, G, B : Natural;
         Count : Natural;
      begin
         for Position in Item.First .. Item.Last loop
            exit when Work_Budgets.Failed (Work);
            if not Charge then
               exit;
            end if;
            Bucket := Histogram.Occupied (Position);
            Count := Histogram.Counts (Bucket);
            R := Arithmetic.Red_Bucket (Bucket);
            G := Arithmetic.Green_Bucket (Bucket);
            B := Arithmetic.Blue_Bucket (Bucket);
            R_Sum := R_Sum
              + Byte_Count (R * 255 / 31) * Byte_Count (Count);
            G_Sum := G_Sum
              + Byte_Count (G * 255 / 31) * Byte_Count (Count);
            B_Sum := B_Sum
              + Byte_Count (B * 255 / 31) * Byte_Count (Count);
            Total := Total + Byte_Count (Count);
         end loop;
         if Total = 0 then
            return (others => 0);
         end if;
         return
           (Byte (R_Sum / Total), Byte (G_Sum / Total),
            Byte (B_Sum / Total));
      end Representative;

      Choice : Natural;
      Best_Range, Spread : Natural;
   begin
      if Opaque_Capacity = 0
        or else Generated_Start > 255
        or else Opaque_Capacity > 256 - Generated_Start
        or else Histogram.Occupied_Count = 0
      then
         return Results.Failure
           (Errors.Make (Errors.Internal_Invariant_Failed));
      end if;
      Boxes (0) :=
        (First => 1,
         Last => Histogram.Occupied_Count,
         others => <>);
      Analyze (Boxes (0));
      Box_Count := (if Boxes (0).Valid then 1 else 0);
      while Box_Count < Opaque_Capacity
        and then not Work_Budgets.Failed (Work)
      loop
         Choice := Box_Count;
         Best_Range := 0;
         for I in 0 .. Box_Count - 1 loop
            Spread := Natural'Max
              (Boxes (I).R_Max - Boxes (I).R_Min,
               Natural'Max
                 (Boxes (I).G_Max - Boxes (I).G_Min,
                  Boxes (I).B_Max - Boxes (I).B_Min));
            if Spread > Best_Range then
               Best_Range := Spread;
               Choice := I;
            end if;
         end loop;
         exit when Choice = Box_Count or else Best_Range = 0;
         Split_Box (Choice);
      end loop;
      if Work_Budgets.Failed (Work) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Resource_Diagnostics.With_Work_Limit
                 (Work, Quantization_Work_Limit)));
      end if;
      for I in 0 .. Box_Count - 1 loop
         Output_Palette.Colors (Palette_Index (Generated_Start + I)) :=
           Representative (Boxes (I));
      end loop;
      if Work_Budgets.Failed (Work) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Resource_Diagnostics.With_Work_Limit
                 (Work, Quantization_Work_Limit)));
      end if;
      Output_Palette.Length := Generated_Start + Box_Count;
      return Results.Success;
   end Build_Median_Cut;
end Giflib.Internal.Quantization_Palette;
