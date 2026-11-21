with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;

with Giflib;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Results;
with Giflib.Streams;
with Giflib_Benchmark_Support;
with Project_Tools.Files;

package body Giflib_Benchmark_File_Workload is
   use Giflib_Benchmark_Support;
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;

   function Read_Input (Path : String) return String is
   begin
      if not Project_Tools.Files.Exists (Path) then
         raise Benchmark_Error with "missing benchmark fixture: " & Path;
      end if;
      return Project_Tools.Files.Read_Raw_File (Path);
   exception
      when Benchmark_Error =>
         raise;
      when Error : others =>
         raise Benchmark_Error with
           "cannot read benchmark fixture " & Path & ": "
           & Ada.Exceptions.Exception_Message (Error);
   end Read_Input;

   procedure Run (Path : String; Enforce : Boolean) is
      Raw : constant String := Read_Input (Path);
      Input : Owned_Buffer;
      Canvas : Owned_Buffer;
      Decode_Times : Duration_Array;
      Transcode_Times : Duration_Array;
      Last_Header : Giflib.Decoding.Header_Info;
      Last_Frames : Natural := 0;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;
      Decode_Batch_Iterations : Positive := 1;
      Transcode_Batch_Iterations : Positive := 1;

      procedure Decode_All
        (Header : out Giflib.Decoding.Header_Info;
         Frame_Count : out Natural)
      is
         Source : aliased
           Giflib.Streams.Memory_Source (Data (Input).all'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Options : Giflib.Decoding.Decode_Options :=
           Giflib.Decoding.Default_Options;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Outcome : Giflib.Results.Result;
      begin
         Frame_Count := 0;
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder, Options);
         Require (Outcome, "decode initialize", Path);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Require (Outcome, "decode header", Path);
         if not Is_Allocated (Canvas) then
            Allocate
              (Canvas,
               Natural (Header.Width) * Natural (Header.Height) * 4);
         end if;
         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "decode event", Path);
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Data (Canvas).all, Info);
               Require (Outcome, "decode frame", Path);
               Frame_Count := Frame_Count + 1;
            end if;
         end loop;
      end Decode_All;

      procedure Transcode_All
        (Header : Giflib.Decoding.Header_Info;
         Expected_Frames : Natural;
         Output_Bytes : out Giflib.Destination_Offset)
      is
         Source : aliased
           Giflib.Streams.Memory_Source (Data (Input).all'Access);
         Destination : aliased Counting_Destination;
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Encoder : Giflib.Encoding.Encoder (Destination'Access);
         Options : Giflib.Decoding.Decode_Options :=
           Giflib.Decoding.Default_Options;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Encode_Info : Giflib.Encoding.Frame_Info;
         Decoded_Header : Giflib.Decoding.Header_Info;
         Outcome : Giflib.Results.Result;
         Encoded_Frames : Natural := 0;
      begin
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder, Options);
         Require (Outcome, "encode-source initialize", Path);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Decoded_Header);
         Require (Outcome, "encode-source header", Path);

         Outcome := Giflib.Encoding.Initialize (Encoder);
         Require (Outcome, "encode initialize", Path);
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder,
            (Width => Header.Width, Height => Header.Height, others => <>));
         Require (Outcome, "encode screen", Path);

         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "encode-source event", Path);
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Data (Canvas).all, Info);
               Require (Outcome, "encode-source frame", Path);
               Encode_Info :=
                 (Width => Header.Width,
                  Height => Header.Height,
                  Control => Info.Control,
                  others => <>);
               declare
                  View : constant Giflib.Images.Image_View :=
                    (Format => Giflib.RGBA_32,
                     Width => Header.Width,
                     Height => Header.Height,
                     Stride =>
                       Giflib.Row_Stride (Natural (Header.Width) * 4),
                     Accessible_Bytes =>
                       Giflib.Byte_Count (Length (Canvas)),
                     Data => Data (Canvas).all'Access);
               begin
                  Outcome := Giflib.Encoding.Add_Truecolor_Frame
                    (Encoder, Encode_Info, View);
               end;
               Require (Outcome, "encode frame", Path);
               Encoded_Frames := Encoded_Frames + 1;
            end if;
         end loop;
         if Encoded_Frames /= Expected_Frames then
            raise Benchmark_Error with
              "frame count changed between benchmark passes";
         end if;
         Outcome := Giflib.Encoding.Finish (Encoder);
         Require (Outcome, "encode finish", Path);
         Output_Bytes := Destination.Offset;
      end Transcode_All;

      procedure Decode_Iteration is
      begin
         Decode_All (Last_Header, Last_Frames);
      end Decode_Iteration;

      procedure Transcode_Iteration is
      begin
         Transcode_All (Last_Header, Last_Frames, Last_Output_Bytes);
      end Transcode_Iteration;

      function Reference_Median
        (Decode : Boolean) return Duration
      is
         Name : constant String := Ada.Directories.Simple_Name (Path);
      begin
         if Name = "docbook-tip.gif" then
            return (if Decode then 0.000012667 else 0.000022122);
         elsif Name = "docbook-warning.gif" then
            return (if Decode then 0.000012717 else 0.000021993);
         elsif Name = "imagemagick-indexed.gif" then
            return (if Decode then 0.000003758 else 0.000006468);
         elsif Name = "imagemagick-animation.gif" then
            return (if Decode then 0.000008230 else 0.000014027);
         elsif Name = "imagemagick-benchmark-animation-256.gif" then
            return (if Decode then 0.006190549 else 0.016789390);
         elsif Name = "imagemagick-interlaced.gif" then
            return (if Decode then 0.000004920 else 0.000008655);
         elsif Name = "imagemagick-benchmark-512.gif" then
            return (if Decode then 0.002571525 else 0.007076847);
         else
            return 0.0;
         end if;
      end Reference_Median;
   begin
      if Raw'Length = 0 then
         raise Benchmark_Error with "empty benchmark fixture: " & Path;
      end if;
      Allocate (Input, Raw'Length);
      for I in Raw'Range loop
         Data (Input) (I - Raw'First + 1) :=
           Giflib.Byte (Character'Pos (Raw (I)));
      end loop;

      Decode_Batch_Iterations := Select_Batch_Iterations
        (Decode_Iteration'Access, Path & " decode");
      Transcode_Batch_Iterations := Select_Batch_Iterations
        (Transcode_Iteration'Access, Path & " transcode");

      for Sample in 1 .. Repeat_Count loop
         Decode_Times (Sample) :=
           Measure_Batch (Decode_Iteration'Access, Decode_Batch_Iterations)
           / Decode_Batch_Iterations;
         Transcode_Times (Sample) :=
           Measure_Batch
             (Transcode_Iteration'Access, Transcode_Batch_Iterations)
           / Transcode_Batch_Iterations;
      end loop;
      Sort (Decode_Times);
      Sort (Transcode_Times);
      if Enforce then
         declare
            Operations : constant Giflib.Byte_Count :=
              Giflib.Byte_Count'Max
                (128,
                 Giflib.Byte_Count (Last_Header.Width)
                   * Giflib.Byte_Count (Last_Header.Height))
              * Giflib.Byte_Count (Natural'Max (1, Last_Frames));
            Decode_Reference : constant Duration :=
              Reference_Median (Decode => True);
            Transcode_Reference : constant Duration :=
              Reference_Median (Decode => False);
            Decode_Ceiling : constant Duration :=
              Baseline_Sensitive_Ceiling
                (Path & " decode",
                 Batched_Throughput_Ceiling
                   (Long_Float (Operations),
                    Decode_Pixels_Per_Second_Floor,
                    Decode_Batch_Iterations),
                 Decode_Reference);
            Transcode_Ceiling : constant Duration :=
              Baseline_Sensitive_Ceiling
                (Path & " transcode",
                 Batched_Throughput_Ceiling
                   (Long_Float (Operations),
                    Transcode_Pixels_Per_Second_Floor,
                    Transcode_Batch_Iterations),
                 Transcode_Reference);
         begin
            Enforce_Time
              (Path & " decode", Decode_Times (3), Decode_Ceiling);
            Enforce_Time
              (Path & " transcode", Transcode_Times (3), Transcode_Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Path
         & " bytes=" & Natural'Image (Length (Input))
         & " canvas=" & Natural'Image (Natural (Last_Header.Width)) & "x"
         & Natural'Image (Natural (Last_Header.Height))
         & " frames=" & Natural'Image (Last_Frames)
         & " samples=" & Natural'Image (Repeat_Count)
         & " decode_batch_iterations="
         & Positive'Image (Decode_Batch_Iterations)
         & " transcode_batch_iterations="
         & Positive'Image (Transcode_Batch_Iterations)
         & " decode_cpu_median_s=" & Duration'Image (Decode_Times (3))
         & " transcode_cpu_median_s=" & Duration'Image (Transcode_Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;
end Giflib_Benchmark_File_Workload;
