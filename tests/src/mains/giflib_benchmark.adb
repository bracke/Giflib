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
   use Ada.Real_Time;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Streams.Byte_Array_Access;

   procedure Free_Bytes is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, Giflib.Streams.Byte_Array_Access);

   procedure Report_Peak_Memory is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/self/status");
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Ada.Strings.Fixed.Index (Line, "VmHWM:") = 1 then
               Ada.Text_IO.Put_Line ("process_" & Line);
               exit;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Ada.Text_IO.Put_Line ("process_peak_rss=unavailable");
   end Report_Peak_Memory;

   procedure Benchmark (Path : String) is
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Input : Giflib.Streams.Byte_Array_Access := null;
      Canvas : Giflib.Streams.Byte_Array_Access := null;
      Encoded : Giflib.Streams.Byte_Array_Access := null;
      Source : aliased Giflib.Streams.Memory_Source;
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Decoder : Giflib.Decoding.Decoder;
      Encoder : Giflib.Encoding.Encoder;
      Decode_Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Outcome : Giflib.Results.Result;
      Frames : Natural := 0;
      Start, Decode_End, Encode_End : Time;
   begin
      if Raw'Length = 0 then
         return;
      end if;
      Input := new Giflib.Streams.Byte_Array (1 .. Raw'Length);
      for I in Raw'Range loop
         Input (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
      end loop;

      Decode_Options.Mode := Giflib.Decoding.Composited_RGBA;
      Giflib.Streams.Open (Source, Input.all'Unchecked_Access);
      Start := Clock;
      Outcome := Giflib.Decoding.Initialize (Decoder, Source'Unchecked_Access, Decode_Options);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      end if;
      if not Giflib.Results.Succeeded (Outcome) then
         raise Program_Error with "decode header failed: " & Path;
      end if;
      Canvas := new Giflib.Streams.Byte_Array
        (1 .. Natural (Header.Width) * Natural (Header.Height) * 4);
      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         if not Giflib.Results.Succeeded (Outcome) then
            raise Program_Error with "decode event failed: " & Path;
         elsif Event.Kind = Giflib.Decoding.End_Event then
            exit;
         elsif Event.Kind = Giflib.Decoding.Image_Event then
            Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas.all, Info);
            if not Giflib.Results.Succeeded (Outcome) then
               raise Program_Error with
                 "decode frame failed: " & Path & " "
                 & Giflib.Errors.Error_Code'Image (Outcome.First_Error.Code);
            end if;
            Frames := Frames + 1;
         end if;
      end loop;
      Decode_End := Clock;

      Encoded := new Giflib.Streams.Byte_Array
        (1 .. Natural'Max (65_536, Canvas'Length * 2 + 1_024));
      Giflib.Streams.Open (Destination, Encoded.all'Unchecked_Access);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Encoding.Define_Screen
           (Encoder, (Width => Header.Width, Height => Header.Height, others => <>));
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         declare
            View : constant Giflib.Images.Image_View :=
              (Format => Giflib.RGBA_32,
               Width => Header.Width,
               Height => Header.Height,
               Stride => Giflib.Row_Stride (Natural (Header.Width) * 4),
               Accessible_Bytes => Giflib.Byte_Count (Canvas'Length),
               Data => Canvas.all'Unchecked_Access);
         begin
            Outcome := Giflib.Encoding.Add_Truecolor_Frame
              (Encoder, (Width => Header.Width, Height => Header.Height, others => <>), View);
         end;
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Encoding.Finish (Encoder);
      end if;
      if not Giflib.Results.Succeeded (Outcome) then
         raise Program_Error with "encode failed: " & Path;
      end if;
      Encode_End := Clock;
      Ada.Text_IO.Put_Line
        (Path
         & " bytes=" & Natural'Image (Input'Length)
         & " canvas=" & Natural'Image (Natural (Header.Width)) & "x"
         & Natural'Image (Natural (Header.Height))
         & " frames=" & Natural'Image (Frames)
         & " decode_s=" & Duration'Image (To_Duration (Decode_End - Start))
         & " encode_s=" & Duration'Image (To_Duration (Encode_End - Decode_End))
         & " output_bytes=" & Giflib.Destination_Offset'Image (Destination.Offset));
      Giflib.Decoding.Finalize (Decoder);
      Giflib.Encoding.Finalize (Encoder);
      Free_Bytes (Encoded);
      Free_Bytes (Canvas);
      Free_Bytes (Input);
   exception
      when others =>
         if Encoded /= null then
            Free_Bytes (Encoded);
         end if;
         if Canvas /= null then
            Free_Bytes (Canvas);
         end if;
         if Input /= null then
            Free_Bytes (Input);
         end if;
         raise;
   end Benchmark;
begin
   if Ada.Command_Line.Argument_Count = 0 then
      Benchmark ("artifacts/giflib-still.gif");
      Benchmark ("artifacts/giflib-animation.gif");
      Benchmark ("artifacts/giflib-truecolor.gif");
   else
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         Benchmark (Ada.Command_Line.Argument (I));
      end loop;
   end if;
   Report_Peak_Memory;
end Giflib_Benchmark;
