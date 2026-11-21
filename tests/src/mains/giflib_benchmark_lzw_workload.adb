with Ada.Exceptions;
with Ada.Text_IO;

with Giflib;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Palettes;
with Giflib.Results;
with Giflib.Streams;
with Giflib_Benchmark_Support;
with Project_Tools.Files;

package body Giflib_Benchmark_LZW_Workload is
   use Giflib_Benchmark_Support;
   use type Giflib.Decoding.Event_Kind;

   procedure Run (Enforce : Boolean) is
      Width : constant := 512;
      Height : constant := 512;
      Pixel_Count : constant := Width * Height;
      Workload : constant String := "synthetic-indexed-lzw-512";
      Pixels : Owned_Buffer;
      Palette : Giflib.Palettes.Palette;
      Times : Duration_Array;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;
      Batch_Iterations : Positive := 1;

      procedure Encode_Once
        (Output_Bytes : out Giflib.Destination_Offset)
      is
         Destination : aliased Counting_Destination;
         Encoder : Giflib.Encoding.Encoder (Destination'Access);
         Outcome : Giflib.Results.Result;
      begin
         Outcome := Giflib.Encoding.Initialize (Encoder);
         Require (Outcome, "LZW initialize", Workload);
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder, (Width => Width, Height => Height, others => <>));
         Require (Outcome, "LZW screen", Workload);
         Outcome := Giflib.Encoding.Add_Indexed_Frame
           (Encoder,
            (Width => Width, Height => Height, others => <>),
            (Selection => Giflib.Encoding.Use_Local_Palette,
             Value => Palette),
            Data (Pixels).all);
         Require (Outcome, "LZW frame", Workload);
         Outcome := Giflib.Encoding.Finish (Encoder);
         Require (Outcome, "LZW finish", Workload);
         Output_Bytes := Destination.Offset;
      end Encode_Once;

      procedure Encode_Iteration is
      begin
         Encode_Once (Last_Output_Bytes);
      end Encode_Iteration;
   begin
      Allocate (Pixels, Pixel_Count);
      Palette.Length := 256;
      for I in Giflib.Palette_Index loop
         Palette.Colors (I) :=
           (Giflib.Byte (I),
            Giflib.Byte (Natural (I) * 73 mod 256),
            Giflib.Byte (Natural (I) * 151 mod 256));
      end loop;
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            Data (Pixels) (Y * Width + X + 1) :=
              Giflib.Byte ((X * 17 + Y * 29 + X * Y mod 251) mod 256);
         end loop;
      end loop;

      Batch_Iterations := Select_Batch_Iterations
        (Encode_Iteration'Access, Workload);
      for Sample in Times'Range loop
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
                 (Long_Float (Pixel_Count),
                  LZW_Encode_Pixels_Per_Second_Floor,
                  Batch_Iterations),
               Reference => 0.00433);
         begin
            Enforce_Time (Workload, Times (3), Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " pixels=" & Natural'Image (Pixel_Count)
         & " batch_iterations=" & Positive'Image (Batch_Iterations)
         & " encode_cpu_median_s=" & Duration'Image (Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;

   procedure Run_Decode (Enforce : Boolean) is
      Width : constant := 512;
      Height : constant := 512;
      Pixel_Count : constant := Width * Height;
      Workload : constant String := "independent-indexed-lzw-decode-512";
      Root : constant String := Repository_Root;
      Path : constant String :=
        (if Root = ""
         then "tests/fixtures/generated/imagemagick-benchmark-512.gif"
         else Project_Tools.Files.Join
           (Root, "tests/fixtures/generated/imagemagick-benchmark-512.gif"));
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Input, Pixels : Owned_Buffer;
      Times : Duration_Array;
      Batch_Iterations : Positive := 1;

      procedure Decode_Once is
         Source : aliased
           Giflib.Streams.Memory_Source (Data (Input).all'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Header : Giflib.Decoding.Header_Info;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Outcome : Giflib.Results.Result;
      begin
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder);
         Require (Outcome, "LZW decode initialize", Workload);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Require (Outcome, "LZW decode header", Workload);
         if Natural (Header.Width) /= Width
           or else Natural (Header.Height) /= Height
         then
            raise Benchmark_Error with
              "indexed LZW fixture dimensions changed";
         end if;
         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "LZW decode event", Workload);
            exit when Event.Kind = Giflib.Decoding.Image_Event;
            if Event.Kind = Giflib.Decoding.End_Event then
               raise Benchmark_Error with
                 "indexed LZW fixture has no image event";
            end if;
         end loop;
         Outcome := Giflib.Decoding.Decode_Indexed_Frame
           (Decoder, Data (Pixels).all, Info);
         Require (Outcome, "LZW indexed decode", Workload);
         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "LZW decode trailer", Workload);
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               raise Benchmark_Error with
                 "indexed LZW fixture gained another image";
            end if;
         end loop;
      end Decode_Once;

      procedure Decode_Iteration is
      begin
         Decode_Once;
      end Decode_Iteration;
   begin
      if Raw'Length = 0 then
         raise Benchmark_Error with "empty indexed LZW fixture";
      end if;
      Allocate (Input, Raw'Length);
      Allocate (Pixels, Pixel_Count);
      for I in Raw'Range loop
         Data (Input) (I - Raw'First + 1) :=
           Giflib.Byte (Character'Pos (Raw (I)));
      end loop;
      Batch_Iterations := Select_Batch_Iterations
        (Decode_Iteration'Access, Workload);
      for Sample in Times'Range loop
         Times (Sample) :=
           Measure_Batch (Decode_Iteration'Access, Batch_Iterations)
           / Batch_Iterations;
      end loop;
      Sort (Times);
      if Enforce then
         declare
            Ceiling : constant Duration := Baseline_Sensitive_Ceiling
              (Workload,
               Batched_Throughput_Ceiling
                 (Long_Float (Pixel_Count),
                  LZW_Decode_Pixels_Per_Second_Floor,
                  Batch_Iterations),
               Reference => 0.00189);
         begin
            Enforce_Time (Workload, Times (3), Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Workload
         & " pixels=" & Natural'Image (Pixel_Count)
         & " batch_iterations=" & Positive'Image (Batch_Iterations)
         & " decode_cpu_median_s=" & Duration'Image (Times (3)));
   exception
      when Benchmark_Error | Performance_Guardrail_Error =>
         raise;
      when Error : others =>
         raise Benchmark_Error with
           "cannot run indexed LZW decode benchmark: "
           & Ada.Exceptions.Exception_Message (Error);
   end Run_Decode;
end Giflib_Benchmark_LZW_Workload;
