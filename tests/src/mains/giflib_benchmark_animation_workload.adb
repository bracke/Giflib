with Ada.Text_IO;

with Giflib;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib_Benchmark_Support;

package body Giflib_Benchmark_Animation_Workload is
   use Giflib_Benchmark_Support;

   procedure Run (Enforce : Boolean) is
      Width : constant := 256;
      Height : constant := 256;
      Frame_Count : constant := 8;
      Pixel_Count : constant := Width * Height;
      Operations : constant := Pixel_Count * Frame_Count;
      Pixels : Owned_Buffer;
      Palette : Giflib.Palettes.Palette;
      Options : Giflib.Quantization.Quantize_Options :=
        Giflib.Quantization.Default_Options;
      Times : Duration_Array;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;
      Workload : constant String := "synthetic-fixed-animation-256x8";
      Batch_Iterations : Positive := 1;

      procedure Encode_Once
        (Output_Bytes : out Giflib.Destination_Offset)
      is
         Destination : aliased Counting_Destination;
         Encoder : Giflib.Encoding.Encoder (Destination'Access);
         Outcome : Giflib.Results.Result;
         View : constant Giflib.Images.Image_View :=
           (Format => Giflib.RGB_24,
            Width => Width,
            Height => Height,
            Stride => Giflib.Row_Stride (Width * 3),
            Accessible_Bytes => Giflib.Byte_Count (Length (Pixels)),
            Data => Data (Pixels).all'Access);
      begin
         Outcome := Giflib.Encoding.Initialize (Encoder);
         Require (Outcome, "animation initialize", Workload);
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder, (Width => Width, Height => Height, others => <>));
         Require (Outcome, "animation screen", Workload);
         for Frame in 1 .. Frame_Count loop
            Outcome := Giflib.Encoding.Add_Truecolor_Frame
              (Encoder,
               (Width => Width, Height => Height,
                Control =>
                  (Has_Transparency => False,
                   Delay_CS => Giflib.Delay_Centiseconds (Frame),
                   others => <>),
                others => <>),
               View,
               Options);
            Require (Outcome, "animation frame", Workload);
         end loop;
         Outcome := Giflib.Encoding.Finish (Encoder);
         Require (Outcome, "animation finish", Workload);
         Output_Bytes := Destination.Offset;
      end Encode_Once;

      procedure Encode_Iteration is
      begin
         Encode_Once (Last_Output_Bytes);
      end Encode_Iteration;
   begin
      Allocate (Pixels, Pixel_Count * 3);
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
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               Position : constant Natural := (Y * Width + X) * 3 + 1;
            begin
               Data (Pixels) (Position) := Giflib.Byte ((X + Y) mod 256);
               Data (Pixels) (Position + 1) :=
                 Giflib.Byte ((X * 3 + Y * 5) mod 256);
               Data (Pixels) (Position + 2) :=
                 Giflib.Byte ((X * 11 + Y * 7) mod 256);
            end;
         end loop;
      end loop;

      Batch_Iterations := Select_Batch_Iterations
        (Encode_Iteration'Access, Workload);
      for Sample in 1 .. Repeat_Count loop
         Times (Sample) :=
           Measure_Batch (Encode_Iteration'Access, Batch_Iterations)
           / Batch_Iterations;
      end loop;
      Sort (Times);
      if Enforce then
         declare
            Ceiling : constant Duration := Baseline_Sensitive_Ceiling
              (Workload,
               Batched_Throughput_Ceiling
                 (Long_Float (Operations),
                  Animation_Pixels_Per_Second_Floor,
                  Batch_Iterations),
               Reference => 0.0891);
         begin
            Enforce_Time (Workload, Times (3), Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " pixels=" & Natural'Image (Operations)
         & " frames=" & Natural'Image (Frame_Count)
         & " batch_iterations=" & Positive'Image (Batch_Iterations)
         & " encode_cpu_median_s=" & Duration'Image (Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;
end Giflib_Benchmark_Animation_Workload;
