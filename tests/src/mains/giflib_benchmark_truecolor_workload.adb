with Ada.Text_IO;

with Giflib;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib_Benchmark_Support;

package body Giflib_Benchmark_Truecolor_Workload is
   use Giflib_Benchmark_Support;
   Cache_Phase_Prefix_Pixels : constant := 4_096;

   procedure Run (Mode : Workload_Mode; Enforce : Boolean) is
      Width : constant := 512;
      Height : constant := 512;
      Pixel_Count : constant := Width * Height;
      Components : constant Positive :=
        (if Mode in Exact_RGBA_Mixed | Fixed_RGBA_Opaque | Dithered_RGBA_Mixed
         then 4 else 3);
      Format : constant Giflib.Pixel_Format :=
        (if Components = 4 then Giflib.RGBA_32 else Giflib.RGB_24);
      Pixels : Owned_Buffer;
      Encode_Times : Duration_Array;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;
      Workload : constant String :=
        (case Mode is
            when Generated => "synthetic-rgb-512",
            when Fixed => "synthetic-fixed-512",
            when Fixed_Repeated => "synthetic-fixed-repeated-512",
            when Fixed_Phased => "synthetic-fixed-phased-512",
            when Dithered => "synthetic-dither-512",
            when Exact_RGBA_Mixed => "synthetic-alpha-exact-255-512",
            when Fixed_RGBA_Opaque => "synthetic-alpha-fixed-opaque-512",
            when Dithered_RGBA_Mixed => "synthetic-alpha-dither-512");
      Reference_Median : constant Duration :=
        (case Mode is
            when Generated => 0.0336,
            when Fixed => 0.0417,
            when Fixed_Repeated => 0.00788,
            when Fixed_Phased => 0.00850,
            when Dithered => 0.0458,
            when Exact_RGBA_Mixed => 0.00437,
            when Fixed_RGBA_Opaque => 0.0412,
            when Dithered_RGBA_Mixed => 0.0424);
      Palette : Giflib.Palettes.Palette;
      Options : Giflib.Quantization.Quantize_Options :=
        Giflib.Quantization.Default_Options;
      Throughput_Floor : Positive;
      Batch_Iterations : Positive := 1;

      procedure Encode_Once
        (Output_Bytes : out Giflib.Destination_Offset)
      is
         Destination : aliased Counting_Destination;
         Encoder : Giflib.Encoding.Encoder (Destination'Access);
         Outcome : Giflib.Results.Result;
         View : constant Giflib.Images.Image_View :=
           (Format => Format,
            Width => Width,
            Height => Height,
            Stride => Giflib.Row_Stride (Width * Components),
            Accessible_Bytes => Giflib.Byte_Count (Length (Pixels)),
            Data => Data (Pixels).all'Access);
      begin
         Outcome := Giflib.Encoding.Initialize (Encoder);
         Require (Outcome, "encode initialize", Workload);
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder, (Width => Width, Height => Height, others => <>));
         Require (Outcome, "encode screen", Workload);
         Outcome := Giflib.Encoding.Add_Truecolor_Frame
           (Encoder,
            (Width => Width, Height => Height, others => <>),
            View,
            Options);
         Require (Outcome, "encode truecolor frame", Workload);
         Outcome := Giflib.Encoding.Finish (Encoder);
         Require (Outcome, "encode finish", Workload);
         Output_Bytes := Destination.Offset;
      end Encode_Once;

      procedure Encode_Iteration is
      begin
         Encode_Once (Last_Output_Bytes);
      end Encode_Iteration;
   begin
      Allocate (Pixels, Pixel_Count * Components);
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               Position : constant Natural :=
                 (Y * Width + X) * Components + 1;
               Exact_Value : constant Natural := (Y * Width + X) mod 255;
            begin
               if Mode = Exact_RGBA_Mixed then
                  Data (Pixels) (Position) := Giflib.Byte (Exact_Value);
                  Data (Pixels) (Position + 1) :=
                    Giflib.Byte (Exact_Value * 73 mod 256);
                  Data (Pixels) (Position + 2) :=
                    Giflib.Byte (Exact_Value * 151 mod 256);
               elsif Mode = Fixed_Repeated then
                  declare
                     Value : constant Natural := (X / 8 + Y / 8) mod 16;
                  begin
                     Data (Pixels) (Position) := Giflib.Byte (Value);
                     Data (Pixels) (Position + 1) :=
                       Giflib.Byte (Value * 37 mod 256);
                     Data (Pixels) (Position + 2) :=
                       Giflib.Byte (Value * 73 mod 256);
                  end;
               elsif Mode = Fixed_Phased
                 and then Y * Width + X >= Cache_Phase_Prefix_Pixels
               then
                  declare
                     Value : constant Natural := (X / 8 + Y / 8) mod 16;
                  begin
                     Data (Pixels) (Position) := Giflib.Byte (Value);
                     Data (Pixels) (Position + 1) :=
                       Giflib.Byte (Value * 37 mod 256);
                     Data (Pixels) (Position + 2) :=
                       Giflib.Byte (Value * 73 mod 256);
                  end;
               else
                  Data (Pixels) (Position) :=
                    Giflib.Byte (X * 255 / (Width - 1));
                  Data (Pixels) (Position + 1) :=
                    Giflib.Byte (Y * 255 / (Height - 1));
                  Data (Pixels) (Position + 2) :=
                    Giflib.Byte ((X * 17 + Y * 29) mod 256);
               end if;
               if Components = 4 then
                  Data (Pixels) (Position + 3) :=
                    (if Mode /= Fixed_RGBA_Opaque
                       and then (X + Y) mod 17 = 0
                     then 0 else 255);
               end if;
            end;
         end loop;
      end loop;

      case Mode is
         when Generated =>
            Throughput_Floor := Encode_Pixels_Per_Second_Floor;
         when Fixed | Fixed_Repeated | Fixed_Phased | Fixed_RGBA_Opaque =>
            Palette.Length := 256;
            for I in Giflib.Palette_Index loop
               Palette.Colors (I) :=
                 (Giflib.Byte (I),
                  Giflib.Byte (Natural (I) * 37 mod 256),
                  Giflib.Byte (Natural (I) * 73 mod 256));
            end loop;
            Options.Palette :=
              (Strategy => Giflib.Quantization.Use_Fixed_Palette,
               Fixed_Palette => Palette,
               Fixed_Transparent_Index => 0);
            if Mode = Fixed_RGBA_Opaque then
               Options.Transparency :=
                 (Enabled => True, Alpha_Threshold => 127);
               Throughput_Floor := Alpha_Fixed_Pixels_Per_Second_Floor;
            elsif Mode = Fixed_Repeated then
               Throughput_Floor := Cache_Friendly_Pixels_Per_Second_Floor;
            elsif Mode = Fixed_Phased then
               Throughput_Floor := Cache_Phased_Pixels_Per_Second_Floor;
            else
               Throughput_Floor := Fixed_Pixels_Per_Second_Floor;
            end if;
         when Dithered | Dithered_RGBA_Mixed =>
            Options.Dither := Giflib.Quantization.Floyd_Steinberg;
            if Mode = Dithered_RGBA_Mixed then
               Options.Transparency :=
                 (Enabled => True, Alpha_Threshold => 127);
               Throughput_Floor := Alpha_Dither_Pixels_Per_Second_Floor;
            else
               Throughput_Floor := Dither_Pixels_Per_Second_Floor;
            end if;
         when Exact_RGBA_Mixed =>
            Options.Transparency :=
              (Enabled => True, Alpha_Threshold => 127);
            Throughput_Floor := Alpha_Exact_Pixels_Per_Second_Floor;
      end case;

      Batch_Iterations := Select_Batch_Iterations
        (Encode_Iteration'Access, Workload);
      for Sample in 1 .. Repeat_Count loop
         Encode_Times (Sample) :=
           Measure_Batch (Encode_Iteration'Access, Batch_Iterations)
           / Batch_Iterations;
      end loop;
      Sort (Encode_Times);
      if Enforce then
         declare
            Ceiling : constant Duration := Baseline_Sensitive_Ceiling
              (Workload & " encode",
               Batched_Throughput_Ceiling
                 (Long_Float (Pixel_Count),
                  Throughput_Floor,
                  Batch_Iterations),
               Reference_Median);
         begin
            Enforce_Time (Workload & " encode", Encode_Times (3), Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " pixels=" & Natural'Image (Pixel_Count)
         & " batch_iterations=" & Positive'Image (Batch_Iterations)
         & (if Mode = Exact_RGBA_Mixed
            then " color_profile=255-exact-alpha"
            elsif Mode = Fixed_Repeated
            then " color_profile=16-repeated"
            elsif Mode = Fixed_Phased
            then " color_profile=phase-changing"
            else " color_profile=>256")
         & " samples=" & Natural'Image (Repeat_Count)
         & " encode_cpu_median_s=" & Duration'Image (Encode_Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;
end Giflib_Benchmark_Truecolor_Workload;
