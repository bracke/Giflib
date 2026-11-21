with Giflib.Internal.Quantization_Arithmetic;

package body Giflib.Internal.Quantization_Box_Operations is
   package Arithmetic renames Giflib.Internal.Quantization_Arithmetic;

   type Color_Axis is (Red_Axis, Green_Axis, Blue_Axis);

   function Charge
     (Work : in out Work_Budgets.Meter;
      Amount : Byte_Count := 1) return Boolean
   is
      Accepted : Boolean;
   begin
      Work_Budgets.Try_Charge (Work, Amount, Accepted);
      return Accepted;
   end Charge;

   function Axis_Value
     (Bucket : Histogram_Data.Histogram_Index;
      Axis : Color_Axis) return Natural
   is
   begin
      case Axis is
         when Red_Axis => return Arithmetic.Red_Bucket (Bucket);
         when Green_Axis => return Arithmetic.Green_Bucket (Bucket);
         when Blue_Axis => return Arithmetic.Blue_Bucket (Bucket);
      end case;
   end Axis_Value;

   function Analyze
     (Histogram : Histogram_Data.Histogram_State;
      First : Histogram_Data.Occupied_Position;
      Last : Histogram_Data.Occupied_Position;
      Work : in out Work_Budgets.Meter) return Box_Result
   is
      Seen : Boolean := False;
      R_Min, R_Max, G_Min, G_Max, B_Min, B_Max : Natural := 0;
      Population : Natural := 0;
   begin
      if not Charge
        (Work, Byte_Count (Natural (Last) - Natural (First) + 1))
      then
         return (Kind => Box_Work_Limit);
      end if;
      for Position in First .. Last loop
         declare
            Bucket : constant Histogram_Data.Histogram_Index :=
              Histogram.Occupied (Position);
            Count : constant Natural := Histogram.Counts (Bucket);
            R : constant Natural := Arithmetic.Red_Bucket (Bucket);
            G : constant Natural := Arithmetic.Green_Bucket (Bucket);
            B : constant Natural := Arithmetic.Blue_Bucket (Bucket);
         begin
            if not Seen then
               R_Min := R;
               R_Max := R;
               G_Min := G;
               G_Max := G;
               B_Min := B;
               B_Max := B;
               Seen := True;
            else
               R_Min := Natural'Min (R_Min, R);
               R_Max := Natural'Max (R_Max, R);
               G_Min := Natural'Min (G_Min, G);
               G_Max := Natural'Max (G_Max, G);
               B_Min := Natural'Min (B_Min, B);
               B_Max := Natural'Max (B_Max, B);
            end if;
            Population := Population + Count;
         end;
      end loop;
      if not Seen then
         return (Kind => Box_Empty);
      end if;
      return
        (Kind => Box_Ready,
         Value =>
           (R_Min => R_Min, R_Max => R_Max,
            G_Min => G_Min, G_Max => G_Max,
            B_Min => B_Min, B_Max => B_Max,
            Population => Population, First => First, Last => Last));
   end Analyze;

   function Spread (Item : Color_Box) return Natural is
     (Natural'Max
        (Item.R_Max - Item.R_Min,
         Natural'Max
           (Item.G_Max - Item.G_Min, Item.B_Max - Item.B_Min)));

   function Split
     (Histogram : in out Histogram_Data.Histogram_State;
      Item : Color_Box;
      Work : in out Work_Budgets.Meter) return Split_Result
   is
      type Axis_Counts is array (Natural range 0 .. 31) of Natural;
      Counts : Axis_Counts := [others => 0];
      Axis : Color_Axis;
      Goal : constant Natural := (Item.Population + 1) / 2;
      Running : Natural := 0;
      Split_At : Natural;
      Left_Position : Integer;
      Right_Position : Integer;
      Partition_Work : Byte_Count := 0;
   begin
      if Spread (Item) = 0 then
         return (Kind => Split_Unavailable);
      elsif Item.R_Max - Item.R_Min >= Item.G_Max - Item.G_Min
        and then Item.R_Max - Item.R_Min >= Item.B_Max - Item.B_Min
      then
         Axis := Red_Axis;
      elsif Item.G_Max - Item.G_Min >= Item.B_Max - Item.B_Min then
         Axis := Green_Axis;
      else
         Axis := Blue_Axis;
      end if;

      if not Charge
        (Work,
         Byte_Count (Natural (Item.Last) - Natural (Item.First) + 1))
      then
         return (Kind => Split_Work_Limit);
      end if;
      for Position in Item.First .. Item.Last loop
         declare
            Bucket : constant Histogram_Data.Histogram_Index :=
              Histogram.Occupied (Position);
            Value : constant Natural := Axis_Value (Bucket, Axis);
         begin
            Counts (Value) := Counts (Value) + Histogram.Counts (Bucket);
         end;
      end loop;

      declare
         Minimum : constant Natural :=
           (case Axis is
               when Red_Axis => Item.R_Min,
               when Green_Axis => Item.G_Min,
               when Blue_Axis => Item.B_Min);
         Maximum : constant Natural :=
           (case Axis is
               when Red_Axis => Item.R_Max,
               when Green_Axis => Item.G_Max,
               when Blue_Axis => Item.B_Max);
      begin
         Split_At := Minimum;
         for Value in Minimum .. Maximum - 1 loop
            Running := Running + Counts (Value);
            Split_At := Value;
            exit when Running >= Goal;
         end loop;
      end;

      Left_Position := Integer (Item.First);
      Right_Position := Integer (Item.Last);
      loop
         while Left_Position <= Integer (Item.Last) loop
            Partition_Work := Partition_Work + 1;
            exit when Axis_Value
              (Histogram.Occupied
                 (Histogram_Data.Occupied_Position (Left_Position)), Axis)
                > Split_At;
            Left_Position := Left_Position + 1;
         end loop;
         while Right_Position >= Integer (Item.First) loop
            Partition_Work := Partition_Work + 1;
            exit when Axis_Value
              (Histogram.Occupied
                 (Histogram_Data.Occupied_Position (Right_Position)), Axis)
                <= Split_At;
            Right_Position := Right_Position - 1;
         end loop;
         exit when Left_Position > Right_Position;
         declare
            Temporary : constant Histogram_Data.Histogram_Index :=
              Histogram.Occupied
                (Histogram_Data.Occupied_Position (Left_Position));
         begin
            Histogram.Occupied
              (Histogram_Data.Occupied_Position (Left_Position)) :=
                Histogram.Occupied
                  (Histogram_Data.Occupied_Position (Right_Position));
            Histogram.Occupied
              (Histogram_Data.Occupied_Position (Right_Position)) := Temporary;
         end;
         Left_Position := Left_Position + 1;
         Right_Position := Right_Position - 1;
      end loop;

      if not Charge (Work, Partition_Work) then
         return (Kind => Split_Work_Limit);
      end if;

      if Right_Position < Integer (Item.First)
        or else Left_Position > Integer (Item.Last)
      then
         return (Kind => Split_Unavailable);
      end if;
      declare
         Left : constant Box_Result :=
           Analyze
             (Histogram, Item.First,
              Histogram_Data.Occupied_Position (Right_Position), Work);
         Right : constant Box_Result :=
           Analyze
             (Histogram, Histogram_Data.Occupied_Position (Left_Position),
              Item.Last, Work);
      begin
         if Left.Kind = Box_Work_Limit or else Right.Kind = Box_Work_Limit then
            return (Kind => Split_Work_Limit);
         elsif Left.Kind /= Box_Ready or else Right.Kind /= Box_Ready then
            return (Kind => Split_Unavailable);
         end if;
         return
           (Kind => Split_Ready, Left => Left.Value, Right => Right.Value);
      end;
   end Split;

   function Representative
     (Histogram : Histogram_Data.Histogram_State;
      Item : Color_Box;
      Work : in out Work_Budgets.Meter) return Representative_Result
   is
      R_Sum, G_Sum, B_Sum, Total : Byte_Count := 0;
   begin
      if not Charge
        (Work,
         Byte_Count (Natural (Item.Last) - Natural (Item.First) + 1))
      then
         return (Kind => Representative_Work_Limit);
      end if;
      for Position in Item.First .. Item.Last loop
         declare
            Bucket : constant Histogram_Data.Histogram_Index :=
              Histogram.Occupied (Position);
            Count : constant Natural := Histogram.Counts (Bucket);
            R : constant Natural := Arithmetic.Red_Bucket (Bucket);
            G : constant Natural := Arithmetic.Green_Bucket (Bucket);
            B : constant Natural := Arithmetic.Blue_Bucket (Bucket);
         begin
            R_Sum := R_Sum + Byte_Count (R * 255 / 31) * Byte_Count (Count);
            G_Sum := G_Sum + Byte_Count (G * 255 / 31) * Byte_Count (Count);
            B_Sum := B_Sum + Byte_Count (B * 255 / 31) * Byte_Count (Count);
            Total := Total + Byte_Count (Count);
         end;
      end loop;
      if Total = 0 then
         return (Kind => Representative_Empty);
      end if;
      return
        (Kind => Representative_Ready,
         Value =>
           (Byte (R_Sum / Total), Byte (G_Sum / Total),
            Byte (B_Sum / Total)));
   end Representative;
end Giflib.Internal.Quantization_Box_Operations;
