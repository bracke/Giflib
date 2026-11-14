with Ada.Exceptions;
with Ada.Real_Time;
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
   use Ada.Real_Time;
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
      Encode_Times : Duration_Array;
      Last_Header : Giflib.Decoding.Header_Info;
      Last_Frames : Natural := 0;
      Last_Output_Bytes : Giflib.Destination_Offset := 0;

      procedure Decode_All
        (Elapsed : out Duration;
         Header : out Giflib.Decoding.Header_Info;
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
         Start, Finish : Time;
      begin
         Frame_Count := 0;
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Start := Clock;
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
         Finish := Clock;
         Elapsed := To_Duration (Finish - Start);
      end Decode_All;

      procedure Encode_All
        (Header : Giflib.Decoding.Header_Info;
         Expected_Frames : Natural;
         Elapsed : out Duration;
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
         Start, Finish : Time;
         Total : Time_Span := Time_Span_Zero;
         Encoded_Frames : Natural := 0;
      begin
         Options.Mode := Giflib.Decoding.Composited_RGBA;
         Giflib.Streams.Open (Source);
         Outcome := Giflib.Decoding.Initialize (Decoder, Options);
         Require (Outcome, "encode-source initialize", Path);
         Outcome := Giflib.Decoding.Read_Header (Decoder, Decoded_Header);
         Require (Outcome, "encode-source header", Path);

         Start := Clock;
         Outcome := Giflib.Encoding.Initialize (Encoder);
         Require (Outcome, "encode initialize", Path);
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder,
            (Width => Header.Width, Height => Header.Height, others => <>));
         Require (Outcome, "encode screen", Path);
         Finish := Clock;
         Total := Total + (Finish - Start);

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
                  Start := Clock;
                  Outcome := Giflib.Encoding.Add_Truecolor_Frame
                    (Encoder, Encode_Info, View);
                  Finish := Clock;
                  Total := Total + (Finish - Start);
               end;
               Require (Outcome, "encode frame", Path);
               Encoded_Frames := Encoded_Frames + 1;
            end if;
         end loop;
         if Encoded_Frames /= Expected_Frames then
            raise Benchmark_Error with
              "frame count changed between benchmark passes";
         end if;
         Start := Clock;
         Outcome := Giflib.Encoding.Finish (Encoder);
         Finish := Clock;
         Total := Total + (Finish - Start);
         Require (Outcome, "encode finish", Path);
         Output_Bytes := Destination.Offset;
         Elapsed := To_Duration (Total);
      end Encode_All;
   begin
      if Raw'Length = 0 then
         raise Benchmark_Error with "empty benchmark fixture: " & Path;
      end if;
      Allocate (Input, Raw'Length);
      for I in Raw'Range loop
         Data (Input) (I - Raw'First + 1) :=
           Giflib.Byte (Character'Pos (Raw (I)));
      end loop;

      for Sample in 1 .. Repeat_Count loop
         Decode_All (Decode_Times (Sample), Last_Header, Last_Frames);
         Encode_All
           (Last_Header, Last_Frames, Encode_Times (Sample),
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
            Enforce_Time
              (Path & " decode", Decode_Times (3), Decode_Ceiling);
            Enforce_Time
              (Path & " encode", Encode_Times (3), Encode_Ceiling);
         end;
      end if;
      Ada.Text_IO.Put_Line
        (Path
         & " bytes=" & Natural'Image (Length (Input))
         & " canvas=" & Natural'Image (Natural (Last_Header.Width)) & "x"
         & Natural'Image (Natural (Last_Header.Height))
         & " frames=" & Natural'Image (Last_Frames)
         & " samples=" & Natural'Image (Repeat_Count)
         & " decode_median_s=" & Duration'Image (Decode_Times (3))
         & " encode_median_s=" & Duration'Image (Encode_Times (3))
         & " output_bytes="
         & Giflib.Destination_Offset'Image (Last_Output_Bytes));
   end Run;
end Giflib_Benchmark_File_Workload;
