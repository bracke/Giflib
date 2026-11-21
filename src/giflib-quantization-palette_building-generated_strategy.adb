with Interfaces;

with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Histograms;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Histogram_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Quantization.Workspace_Operations;

package body Giflib.Quantization.Palette_Building.Generated_Strategy is
   use type Interfaces.Unsigned_32;
   package Arithmetic renames Internal.Quantization_Arithmetic;
   package Histogram renames
     Internal.Quantization_Storage.Histogram_Operations;
   package Outcomes renames Internal.Quantization_Storage.Outcomes;
   package Pixels renames Internal.Quantization_Pixels;
   use type Outcomes.Budgeted_Status;
   use type Outcomes.Storage_Status;

   Exact_Table_Capacity : constant := 512;
   subtype Stored_Exact_Key is Natural range 0 .. 16#1_000000#;
   type Exact_Color_Slot is record
      Key_Plus_One : Stored_Exact_Key := 0;
      Value : Palette_Index := 0;
   end record;
   type Exact_Color_Table is array
     (Natural range 0 .. Exact_Table_Capacity - 1) of Exact_Color_Slot;
   type Exact_Count_Array is array (Palette_Index) of Natural;
   type Exact_Color_Set is record
      Values : Palettes.Color_Array := [others => (others => 0)];
      Slots : Exact_Color_Table := [others => (others => <>)];
      Counts : Exact_Count_Array := [others => 0];
      Count : Natural := 0;
      Overflowed : Boolean := False;
   end record;

   function Exact_Start (Key : Natural) return Natural is
      Mixed : Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Key);
   begin
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 12);
      Mixed := Mixed * 16#9E37_79B1#;
      Mixed := Mixed xor Interfaces.Shift_Right (Mixed, 16);
      return
        Natural
          (Mixed mod Interfaces.Unsigned_32 (Exact_Table_Capacity));
   end Exact_Start;

   function Charge
     (Work : in out Internal.Work_Budgets.Meter;
      Amount : Byte_Count := 1) return Boolean
   is
      Accepted : Boolean;
   begin
      Internal.Work_Budgets.Try_Charge (Work, Amount, Accepted);
      return Accepted;
   end Charge;

   function Collect_Exact
     (Source : Images.Image_View;
      Indexed_Pixels : in out Streams.Byte_Array;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : in out Prepared_Palette;
      Exact : in out Exact_Color_Set;
      Resume_At : out Natural) return Results.Result
   is
      procedure Register_Exact
        (Color : Palettes.RGB_Color;
         Value : out Palette_Index;
         Probe_Work : out Byte_Count;
         Overflowed : out Boolean;
         Valid : out Boolean)
      is
         Key : constant Natural := Pixels.Color_Key (Color);
         Stored_Key : constant Stored_Exact_Key := Stored_Exact_Key (Key + 1);
         Start : constant Natural := Exact_Start (Key);
         Slot : Natural;
      begin
         Value := 0;
         Probe_Work := 0;
         Overflowed := False;
         Valid := True;
         for Offset in 0 .. Exact_Table_Capacity - 1 loop
            Slot := (Start + Offset) mod Exact_Table_Capacity;
            if Exact.Slots (Slot).Key_Plus_One = 0 then
               Probe_Work := Byte_Count (Offset + 1);
               if Exact.Count = 256 then
                  Exact.Overflowed := True;
                  Overflowed := True;
               else
                  Value := Palette_Index (Exact.Count);
                  Exact.Values (Palette_Index (Exact.Count)) := Color;
                  Exact.Counts (Value) := 1;
                  Exact.Slots (Slot) :=
                    (Key_Plus_One => Stored_Key, Value => Value);
                  Exact.Count := Exact.Count + 1;
               end if;
               return;
            elsif Exact.Slots (Slot).Key_Plus_One = Stored_Key then
               Probe_Work := Byte_Count (Offset + 1);
               Value := Exact.Slots (Slot).Value;
               if Exact.Counts (Value) = Natural'Last then
                  Valid := False;
               else
                  Exact.Counts (Value) := Exact.Counts (Value) + 1;
               end if;
               return;
            end if;
         end loop;
         Probe_Work := Exact_Table_Capacity;
         Valid := False;
      end Register_Exact;
      pragma Inline (Register_Exact);

      generic
         with function Read
           (Source : Images.Image_View;
            Position : Positive) return Pixels.Source_Pixel;
         Bytes_Per_Pixel : Positive;
         Has_Alpha : Boolean;
      function Collect_Formatted return Results.Result;

      function Collect_Formatted return Results.Result is
         Pixel : Pixels.Source_Pixel;
         Exact_Index : Palette_Index;
         Output_Position : Natural := 0;
         Position : Positive;
         Probe_Work, Row_Probe_Work : Byte_Count;
         Overflowed, Valid : Boolean;
      begin
         for Y in 0 .. Natural (Source.Height) - 1 loop
            if not Charge (Work, Byte_Count (Source.Width)) then
               return Workspace_Operations.Work_Failure (Work);
            end if;
            Row_Probe_Work := 0;
            Position := Pixels.Row_Start (Source, Y);
            for X in 0 .. Natural (Source.Width) - 1 loop
               Pixel := Read (Source, Position);
               if Has_Alpha
                 and then Options.Transparency.Enabled
                 and then Pixel.Alpha <= Options.Transparency.Alpha_Threshold
               then
                  Prepared.Has_Transparency := True;
                  Indexed_Pixels (Indexed_Pixels'First + Output_Position) :=
                    Byte'Last;
               else
                  Register_Exact
                    (Pixel.Color, Exact_Index, Probe_Work, Overflowed, Valid);
                  Row_Probe_Work := Row_Probe_Work + Probe_Work;
                  if not Valid then
                     if not Charge (Work, Row_Probe_Work) then
                        return Workspace_Operations.Work_Failure (Work);
                     end if;
                     return Workspace_Operations.Invariant_Failure;
                  elsif Overflowed then
                     if not Charge (Work, Row_Probe_Work) then
                        return Workspace_Operations.Work_Failure (Work);
                     end if;
                     Resume_At := Output_Position;
                     return Results.Success;
                  end if;
                  Indexed_Pixels (Indexed_Pixels'First + Output_Position) :=
                    Byte (Exact_Index);
               end if;
               Output_Position := Output_Position + 1;
               Position := Position + Bytes_Per_Pixel;
            end loop;
            if not Charge (Work, Row_Probe_Work) then
               return Workspace_Operations.Work_Failure (Work);
            end if;
         end loop;
         Resume_At := Output_Position;
         return Results.Success;
      end Collect_Formatted;

      function Collect_Indexed is new Collect_Formatted
        (Pixels.Read_Indexed_8_Validated, 1, False);
      function Collect_RGB is new Collect_Formatted
        (Pixels.Read_RGB_24_Validated, 3, False);
      function Collect_BGR is new Collect_Formatted
        (Pixels.Read_BGR_24_Validated, 3, False);
      function Collect_RGBA is new Collect_Formatted
        (Pixels.Read_RGBA_32_Validated, 4, True);
      function Collect_BGRA is new Collect_Formatted
        (Pixels.Read_BGRA_32_Validated, 4, True);
   begin
      Resume_At := 0;
      return
        (case Source.Format is
           when Indexed_8 => Collect_Indexed,
           when RGB_24 => Collect_RGB,
           when BGR_24 => Collect_BGR,
           when RGBA_32 => Collect_RGBA,
           when BGRA_32 => Collect_BGRA);
   end Collect_Exact;

   function Collect_Histogram
     (Context : in out Workspace;
      Source : Images.Image_View;
      Options : Quantize_Options;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : in out Prepared_Palette;
      Exact : Exact_Color_Set;
      Resume_At : Natural) return Results.Result
   is
      Outcome : Results.Result := Results.Success;
      Update_Status : Outcomes.Storage_Status;

      procedure Collect_Remaining
        (State : in out Histogram.Histogram_State)
      is
         Width : constant Natural := Natural (Source.Width);
         Start_Y : constant Natural := Resume_At / Width;
         Start_X : constant Natural := Resume_At mod Width;

         generic
            with function Read
              (Source : Images.Image_View;
               Position : Positive) return Pixels.Source_Pixel;
            Bytes_Per_Pixel : Positive;
            Has_Alpha : Boolean;
         procedure Collect_Formatted;

         procedure Collect_Formatted is
            Pixel : Pixels.Source_Pixel;
            Position : Positive;
            First_X : Natural;
         begin
            for Y in Start_Y .. Natural (Source.Height) - 1 loop
               First_X := (if Y = Start_Y then Start_X else 0);
               if Y > Start_Y
                 and then not Charge (Work, Byte_Count (Source.Width))
               then
                  Outcome := Workspace_Operations.Work_Failure (Work);
                  return;
               end if;
               Position := Pixels.Row_Start (Source, Y)
                 + First_X * Bytes_Per_Pixel;
               for X in First_X .. Width - 1 loop
                  Pixel := Read (Source, Position);
                  if Has_Alpha
                    and then Options.Transparency.Enabled
                    and then
                      Pixel.Alpha <= Options.Transparency.Alpha_Threshold
                  then
                     Prepared.Has_Transparency := True;
                  elsif not Internal.Quantization_Histograms.Add_Sample
                    (State, Arithmetic.Histogram_Of (Pixel.Color))
                  then
                     Outcome := Workspace_Operations.Invariant_Failure;
                     return;
                  end if;
                  Position := Position + Bytes_Per_Pixel;
               end loop;
            end loop;
         end Collect_Formatted;

         procedure Collect_Indexed is new Collect_Formatted
           (Pixels.Read_Indexed_8_Validated, 1, False);
         procedure Collect_RGB is new Collect_Formatted
           (Pixels.Read_RGB_24_Validated, 3, False);
         procedure Collect_BGR is new Collect_Formatted
           (Pixels.Read_BGR_24_Validated, 3, False);
         procedure Collect_RGBA is new Collect_Formatted
           (Pixels.Read_RGBA_32_Validated, 4, True);
         procedure Collect_BGRA is new Collect_Formatted
           (Pixels.Read_BGRA_32_Validated, 4, True);
      begin
         if Exact.Count > 0 then
            for I in 0 .. Exact.Count - 1 loop
               if not Internal.Quantization_Histograms.Add_Count
                 (State,
                  Arithmetic.Histogram_Of (Exact.Values (Palette_Index (I))),
                  Exact.Counts (Palette_Index (I)))
               then
                  Outcome := Workspace_Operations.Invariant_Failure;
                  return;
               end if;
            end loop;
         end if;
         case Source.Format is
            when Indexed_8 => Collect_Indexed;
            when RGB_24 => Collect_RGB;
            when BGR_24 => Collect_BGR;
            when RGBA_32 => Collect_RGBA;
            when BGRA_32 => Collect_BGRA;
         end case;
      end Collect_Remaining;
   begin
      if not Charge (Work, Byte_Count (Exact.Count)) then
         return Workspace_Operations.Work_Failure (Work);
      end if;
      Update_Status := Histogram.Update
        (Context.Resources, Collect_Remaining'Access);
      if Update_Status /= Outcomes.Storage_Ready then
         return Workspace_Operations.Invariant_Failure;
      end if;
      return Outcome;
   end Collect_Histogram;

   function Finish
     (Context : in out Workspace;
      Options : Quantize_Options;
      Indexed_Pixels : in out Streams.Byte_Array;
      Work : in out Internal.Work_Budgets.Meter;
      Exact : Exact_Color_Set;
      Prepared : in out Prepared_Palette) return Results.Result
   is
      Opaque_Capacity : Natural;
      Outcome : Results.Result;
   begin
      Prepared.Generated_Start := (if Prepared.Has_Transparency then 1 else 0);
      if Prepared.Has_Transparency then
         Prepared.Transparent_Index := 0;
         Prepared.Value.Colors (0) := (others => 0);
      end if;
      Opaque_Capacity := Options.Palette.Maximum_Colors - Prepared.Generated_Start;
      if not Exact.Overflowed and then Exact.Count <= Opaque_Capacity then
         if Exact.Count > 0 then
            for I in 0 .. Exact.Count - 1 loop
               Prepared.Value.Colors
                 (Palette_Index (Prepared.Generated_Start + I)) :=
                   Exact.Values (Palette_Index (I));
            end loop;
         end if;
         Prepared.Value.Length := Prepared.Generated_Start + Exact.Count;
         if Prepared.Has_Transparency then
            if not Charge (Work, Byte_Count (Indexed_Pixels'Length)) then
               return Workspace_Operations.Work_Failure (Work);
            end if;
            for Value of Indexed_Pixels loop
               if Value = Byte'Last then
                  Value := 0;
               else
                  Value := Value + 1;
               end if;
            end loop;
         end if;
         Prepared.Pixels_Are_Mapped := True;
      else
         Outcome := Histogram.Build_Median_Cut
           (Context.Resources, Prepared.Generated_Start, Opaque_Capacity, Work,
            Prepared.Value);
         if not Results.Succeeded (Outcome) then return Outcome; end if;
      end if;
      if Prepared.Value.Length < 2 then
         Prepared.Value.Length := 2;
         Prepared.Value.Colors (1) := Prepared.Value.Colors (0);
      end if;
      return Results.Success;
   end Finish;

   function Build
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : in out Streams.Byte_Array;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Prepared : out Prepared_Palette) return Results.Result
   is
      Exact : Exact_Color_Set;
      Reset_Status : Outcomes.Budgeted_Status;
      Outcome : Results.Result;
      Resume_At : Natural;
   begin
      Prepared := (others => <>);
      Outcome := Collect_Exact
        (Source, Indexed_Pixels, Options, Work, Prepared, Exact, Resume_At);
      if not Results.Succeeded (Outcome) then return Outcome; end if;
      if Exact.Overflowed
        or else Exact.Count >
          Options.Palette.Maximum_Colors
            - (if Prepared.Has_Transparency then 1 else 0)
      then
         Outcome := Workspace_Operations.Ensure_Histogram
           (Context, Constraints);
         if not Results.Succeeded (Outcome) then return Outcome; end if;
         Reset_Status := Histogram.Reset (Context.Resources, Work);
         if Reset_Status = Outcomes.Budgeted_Work_Limit then
            return Workspace_Operations.Work_Failure (Work);
         elsif Reset_Status /= Outcomes.Budgeted_Ready then
            return Workspace_Operations.Invariant_Failure;
         end if;
         Outcome := Collect_Histogram
           (Context, Source, Options, Work, Prepared, Exact, Resume_At);
         if not Results.Succeeded (Outcome) then return Outcome; end if;
      end if;
      return Finish
        (Context, Options, Indexed_Pixels, Work, Exact, Prepared);
   end Build;
end Giflib.Quantization.Palette_Building.Generated_Strategy;
