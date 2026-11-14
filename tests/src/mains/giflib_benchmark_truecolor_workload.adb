with Ada.Real_Time;
with Ada.Text_IO;

with Giflib;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Results;
with Giflib_Benchmark_Support;

package body Giflib_Benchmark_Truecolor_Workload is
   use Ada.Real_Time;
   use Giflib_Benchmark_Support;

   procedure Run (Enforce : Boolean) is
      Width : constant := 512;
      Height : constant := 512;
      Pixel_Count : constant := Width * Height;
      Pixels : Owned_Buffer;
      Encode_Times : Duration_Array;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;
      Workload : constant String := "synthetic-rgb-512";
   begin
      Allocate (Pixels, Pixel_Count * 3);
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               Position : constant Natural := (Y * Width + X) * 3 + 1;
            begin
               Data (Pixels) (Position) :=
                 Giflib.Byte (X * 255 / (Width - 1));
               Data (Pixels) (Position + 1) :=
                 Giflib.Byte (Y * 255 / (Height - 1));
               Data (Pixels) (Position + 2) :=
                 Giflib.Byte ((X * 17 + Y * 29) mod 256);
            end;
         end loop;
      end loop;

      for Sample in 1 .. Repeat_Count loop
         declare
            Destination : aliased Counting_Destination;
            Encoder : Giflib.Encoding.Encoder (Destination'Access);
            Outcome : Giflib.Results.Result;
            Start, Finish : Time;
            View : constant Giflib.Images.Image_View :=
              (Format => Giflib.RGB_24,
               Width => Width,
               Height => Height,
               Stride => Giflib.Row_Stride (Width * 3),
               Accessible_Bytes => Giflib.Byte_Count (Length (Pixels)),
               Data => Data (Pixels).all'Access);
         begin
            Start := Clock;
            Outcome := Giflib.Encoding.Initialize (Encoder);
            Require (Outcome, "encode initialize", Workload);
            Outcome := Giflib.Encoding.Define_Screen
              (Encoder, (Width => Width, Height => Height, others => <>));
            Require (Outcome, "encode screen", Workload);
            Outcome := Giflib.Encoding.Add_Truecolor_Frame
              (Encoder,
               (Width => Width, Height => Height, others => <>),
               View);
            Require (Outcome, "encode truecolor frame", Workload);
            Outcome := Giflib.Encoding.Finish (Encoder);
            Finish := Clock;
            Require (Outcome, "encode finish", Workload);
            Encode_Times (Sample) := To_Duration (Finish - Start);
            Last_Output_Bytes := Destination.Offset;
         end;
      end loop;
      Sort (Encode_Times);
      if Enforce then
         Enforce_Time
           (Workload & " encode", Encode_Times (3),
            0.02 + Duration (Long_Float (Pixel_Count) / 250_000.0));
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " pixels=" & Natural'Image (Pixel_Count)
         & " distinct_colors=>256"
         & " samples=" & Natural'Image (Repeat_Count)
         & " encode_median_s=" & Duration'Image (Encode_Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;
end Giflib_Benchmark_Truecolor_Workload;
