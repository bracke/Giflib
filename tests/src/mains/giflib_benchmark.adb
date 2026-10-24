with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Real_Time;
with Ada.Unchecked_Deallocation;

with Giflib;
with Giflib.Decoding;
with Giflib.Encoding;
with Giflib.Errors;
with Giflib.Images;
with Giflib.Results;
with Giflib.Streams;
with Project_Tools.Files;

procedure Giflib_Benchmark is
   type Byte_Array_Access is access all Giflib.Streams.Byte_Array;
   use Ada.Real_Time;
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Destination_Offset;

   Repeat_Count : constant := 5;
   type Duration_Array is array (Positive range 1 .. Repeat_Count) of Duration;

   procedure Free_Bytes is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, Byte_Array_Access);

   type Counting_Destination is limited new Giflib.Streams.Destination with record
      Position : Giflib.Destination_Offset := 0;
   end record;

   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result;
   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset;
   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error;

   overriding function Write
     (Object : in out Counting_Destination;
      Buffer : Giflib.Streams.Byte_Array) return Giflib.Streams.Destination_Result
   is
   begin
      Object.Position := Object.Position
        + Giflib.Destination_Offset (Buffer'Length);
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Buffer'Length));
   end Write;

   overriding function Offset
     (Object : Counting_Destination) return Giflib.Destination_Offset
   is (Object.Position);

   overriding function Flush
     (Object : in out Counting_Destination) return Giflib.Errors.Error
   is
      pragma Unreferenced (Object);
   begin
      return Giflib.Errors.Make (Giflib.Errors.No_Error);
   end Flush;

   procedure Sort (Values : in out Duration_Array) is
      Item : Duration;
      Position : Positive;
   begin
      for I in Values'First + 1 .. Values'Last loop
         Item := Values (I);
         Position := I;
         while Position > Values'First
           and then Values (Position - 1) > Item
         loop
            Values (Position) := Values (Position - 1);
            Position := Position - 1;
         end loop;
         Values (Position) := Item;
      end loop;
   end Sort;

   function Report_Peak_Memory return Natural is
      File : Ada.Text_IO.File_Type;
      Peak_KiB : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/self/status");
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Ada.Strings.Fixed.Index (Line, "VmHWM:") = 1 then
               declare
                  First : Natural := Line'First;
                  Last : Natural;
               begin
                  while First <= Line'Last
                    and then Line (First) not in '0' .. '9'
                  loop
                     First := First + 1;
                  end loop;
                  Last := First;
                  while Last < Line'Last
                    and then Line (Last + 1) in '0' .. '9'
                  loop
                     Last := Last + 1;
                  end loop;
                  Peak_KiB := Natural'Value (Line (First .. Last));
               end;
               exit;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      Ada.Text_IO.Put_Line
        ("process_peak_rss_kib=" & Natural'Image (Peak_KiB));
      return Peak_KiB;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Ada.Text_IO.Put_Line ("process_peak_rss_kib=unavailable");
         return 0;
   end Report_Peak_Memory;

   procedure Enforce_Time
     (Label : String;
      Observed : Duration;
      Ceiling : Duration)
   is
   begin
      if Observed > Ceiling then
         raise Program_Error with
           Label & " performance guardrail exceeded: observed"
           & Duration'Image (Observed) & " ceiling" & Duration'Image (Ceiling);
      end if;
   end Enforce_Time;

   procedure Benchmark (Path : String; Enforce : Boolean) is
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Input : Byte_Array_Access := null;
      Canvas : Byte_Array_Access := null;
      Decode_Times : Duration_Array;
      Encode_Times : Duration_Array;
      Last_Header : Giflib.Decoding.Header_Info;
      Last_Frames : Natural := 0;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;

      procedure Require
        (Outcome : Giflib.Results.Result;
         Operation : String)
      is
      begin
         if not Giflib.Results.Succeeded (Outcome) then
            raise Program_Error with
              Operation & " failed: " & Path & " "
              & Giflib.Errors.Error_Code'Image (Outcome.First_Error.Code);
         end if;
      end Require;

      procedure Decode_All
        (Elapsed : out Duration;
         Header : out Giflib.Decoding.Header_Info;
         Frame_Count : out Natural)
      is
         Source : aliased Giflib.Streams.Memory_Source (Input.all'Access);
         Decoder : Giflib.Decoding.Decoder (Source'Access);
         Options : Giflib.Decoding.Decode_Options :=
           Giflib.Decoding.Default_Options;
         Event : Giflib.Decoding.Decode_Event;
         Info : Giflib.Decoding.Frame_Info;
         Outcome : Giflib.Results.Result;
         Start, Finish : Time;
      begin
         Frame_Count := 0;
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Start := Clock;
         Outcome := Giflib.Decoding.Initialize
           (Decoder, Options);
         Require (Outcome, "decode initialize");
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
         Require (Outcome, "decode header");
         if Canvas = null then
            Canvas := new Giflib.Streams.Byte_Array
              (1 .. Natural (Header.Width) * Natural (Header.Height) * 4);
         end if;
         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "decode event");
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Canvas.all, Info);
               Require (Outcome, "decode frame");
               Frame_Count := Frame_Count + 1;
            end if;
         end loop;
         Finish := Clock;
         Elapsed := To_Duration (Finish - Start);
         Giflib.Decoding.Finalize (Decoder);
      exception
         when others =>
            Giflib.Decoding.Finalize (Decoder);
            raise;
      end Decode_All;

      procedure Encode_All
        (Header : Giflib.Decoding.Header_Info;
         Expected_Frames : Natural;
         Elapsed : out Duration;
         Output_Bytes : out Giflib.Destination_Offset)
      is
         Source : aliased Giflib.Streams.Memory_Source (Input.all'Access);
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
         Start, Finish : Time;
         Total : Time_Span := Time_Span_Zero;
         Encoded_Frames : Natural := 0;
      begin
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize
           (Decoder, Options);
         Require (Outcome, "encode-source initialize");
         Outcome := Giflib.Decoding.Read_Header (Decoder, Decoded_Header);
         Require (Outcome, "encode-source header");

         Start := Clock;
         Outcome := Giflib.Encoding.Initialize
           (Encoder);
         Require (Outcome, "encode initialize");
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder, (Width => Header.Width, Height => Header.Height, others => <>));
         Require (Outcome, "encode screen");
         Finish := Clock;
         Total := Total + (Finish - Start);

         loop
            Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
            Require (Outcome, "encode-source event");
            exit when Event.Kind = Giflib.Decoding.End_Event;
            if Event.Kind = Giflib.Decoding.Image_Event then
               Outcome := Giflib.Decoding.Decode_Composited_Frame
                 (Decoder, Canvas.all, Info);
               Require (Outcome, "encode-source frame");
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
                     Stride => Giflib.Row_Stride (Natural (Header.Width) * 4),
                     Accessible_Bytes => Giflib.Byte_Count (Canvas'Length),
                     Data => Canvas.all'Access);
               begin
                  Start := Clock;
                  Outcome := Giflib.Encoding.Add_Truecolor_Frame
                    (Encoder, Encode_Info, View);
                  Finish := Clock;
                  Total := Total + (Finish - Start);
               end;
               Require (Outcome, "encode frame");
               Encoded_Frames := Encoded_Frames + 1;
            end if;
         end loop;
         if Encoded_Frames /= Expected_Frames then
            raise Program_Error with "frame count changed between benchmark passes";
         end if;
         Start := Clock;
         Outcome := Giflib.Encoding.Finish (Encoder);
         Finish := Clock;
         Total := Total + (Finish - Start);
         Require (Outcome, "encode finish");
         Output_Bytes := Destination.Offset;
         Elapsed := To_Duration (Total);
         Giflib.Decoding.Finalize (Decoder);
         Giflib.Encoding.Finalize (Encoder);
      exception
         when others =>
            Giflib.Decoding.Finalize (Decoder);
            Giflib.Encoding.Finalize (Encoder);
            raise;
      end Encode_All;
   begin
      if Raw'Length = 0 then
         return;
      end if;
      Input := new Giflib.Streams.Byte_Array (1 .. Raw'Length);
      for I in Raw'Range loop
         Input (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
      end loop;

      for Sample in 1 .. Repeat_Count loop
         Decode_All (Decode_Times (Sample), Last_Header, Last_Frames);
         Encode_All
           (Last_Header,
            Last_Frames,
            Encode_Times (Sample),
            Last_Output_Bytes);
      end loop;
      Sort (Decode_Times);
      Sort (Encode_Times);
      if Enforce then
         declare
            Operations : constant Giflib.Byte_Count :=
              Giflib.Byte_Count (Last_Header.Width)
              * Giflib.Byte_Count (Last_Header.Height)
              * Giflib.Byte_Count (Natural'Max (1, Last_Frames));
            Decode_Ceiling : constant Duration :=
              0.02 + Duration (Long_Float (Operations) / 400_000.0);
            Encode_Ceiling : constant Duration :=
              0.02 + Duration (Long_Float (Operations) / 250_000.0);
         begin
            Enforce_Time (Path & " decode", Decode_Times (3), Decode_Ceiling);
            Enforce_Time (Path & " encode", Encode_Times (3), Encode_Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Path
         & " bytes=" & Natural'Image (Input'Length)
         & " canvas=" & Natural'Image (Natural (Last_Header.Width)) & "x"
         & Natural'Image (Natural (Last_Header.Height))
         & " frames=" & Natural'Image (Last_Frames)
         & " samples=" & Natural'Image (Repeat_Count)
         & " decode_median_s=" & Duration'Image (Decode_Times (3))
         & " encode_median_s=" & Duration'Image (Encode_Times (3))
         & " output_bytes=" & Giflib.Destination_Offset'Image (Last_Output_Bytes));
      Free_Bytes (Canvas);
      Free_Bytes (Input);
   exception
      when others =>
         if Canvas /= null then
            Free_Bytes (Canvas);
         end if;
         if Input /= null then
            Free_Bytes (Input);
         end if;
         raise;
   end Benchmark;

   procedure Benchmark_Raw_Truecolor (Enforce : Boolean) is
      Width : constant := 512;
      Height : constant := 512;
      Pixel_Count : constant := Width * Height;
      Data : Byte_Array_Access := null;
      Encode_Times : Duration_Array;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;

      procedure Require
        (Outcome : Giflib.Results.Result;
         Operation : String)
      is
      begin
         if not Giflib.Results.Succeeded (Outcome) then
            raise Program_Error with
              Operation & " failed: synthetic-rgb-512 "
              & Giflib.Errors.Error_Code'Image (Outcome.First_Error.Code);
         end if;
      end Require;
   begin
      Data := new Giflib.Streams.Byte_Array (1 .. Pixel_Count * 3);
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               Position : constant Natural := (Y * Width + X) * 3 + 1;
            begin
               Data (Position) := Giflib.Byte (X * 255 / (Width - 1));
               Data (Position + 1) := Giflib.Byte (Y * 255 / (Height - 1));
               Data (Position + 2) := Giflib.Byte ((X * 17 + Y * 29) mod 256);
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
               Accessible_Bytes => Giflib.Byte_Count (Data'Length),
               Data => Data.all'Access);
         begin
            Start := Clock;
            Outcome := Giflib.Encoding.Initialize
              (Encoder);
            Require (Outcome, "encode initialize");
            Outcome := Giflib.Encoding.Define_Screen
              (Encoder, (Width => Width, Height => Height, others => <>));
            Require (Outcome, "encode screen");
            Outcome := Giflib.Encoding.Add_Truecolor_Frame
              (Encoder, (Width => Width, Height => Height, others => <>), View);
            Require (Outcome, "encode truecolor frame");
            Outcome := Giflib.Encoding.Finish (Encoder);
            Finish := Clock;
            Require (Outcome, "encode finish");
            Encode_Times (Sample) := To_Duration (Finish - Start);
            Last_Output_Bytes := Destination.Offset;
            Giflib.Encoding.Finalize (Encoder);
         exception
            when others =>
               Giflib.Encoding.Finalize (Encoder);
               raise;
         end;
      end loop;
      Sort (Encode_Times);
      if Enforce then
         Enforce_Time
           ("synthetic-rgb-512 encode",
            Encode_Times (3),
            0.02 + Duration (Long_Float (Pixel_Count) / 250_000.0));
      end if;
      Ada.Text_IO.Put_Line
        ("synthetic-rgb-512"
         & " pixels=" & Natural'Image (Pixel_Count)
         & " distinct_colors=>256"
         & " samples=" & Natural'Image (Repeat_Count)
         & " encode_median_s=" & Duration'Image (Encode_Times (3))
         & " output_bytes=" & Giflib.Destination_Offset'Image (Last_Output_Bytes));
      Free_Bytes (Data);
   exception
      when others =>
         if Data /= null then
            Free_Bytes (Data);
         end if;
         raise;
   end Benchmark_Raw_Truecolor;

   Enforce : Boolean := False;
   Run_Synthetic : Boolean := False;
   Ran_Workload : Boolean := False;
begin
   Ada.Text_IO.Put_Line ("benchmark_samples=" & Natural'Image (Repeat_Count));
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (I) = "--enforce" then
         Enforce := True;
      elsif Ada.Command_Line.Argument (I) = "--synthetic-truecolor" then
         Run_Synthetic := True;
      end if;
   end loop;

   for I in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Argument : constant String := Ada.Command_Line.Argument (I);
      begin
         if Argument = "--enforce" or else Argument = "--synthetic-truecolor" then
            null;
         elsif Argument'Length > 0 and then Argument (Argument'First) = '-' then
            raise Program_Error with "unknown benchmark option: " & Argument;
         else
            Benchmark (Argument, Enforce);
            Ran_Workload := True;
         end if;
      end;
   end loop;
   if Run_Synthetic then
      Benchmark_Raw_Truecolor (Enforce);
      Ran_Workload := True;
   end if;
   if not Ran_Workload then
      Benchmark ("artifacts/giflib-still.gif", Enforce);
      Benchmark ("artifacts/giflib-animation.gif", Enforce);
      Benchmark ("artifacts/giflib-truecolor.gif", Enforce);
      Benchmark_Raw_Truecolor (Enforce);
   end if;
   declare
      Peak_KiB : constant Natural := Report_Peak_Memory;
   begin
      if Enforce and then (Peak_KiB = 0 or else Peak_KiB > 65_536) then
         raise Program_Error with
           "benchmark peak-memory guardrail exceeded or unavailable";
      end if;
   end;
end Giflib_Benchmark;
