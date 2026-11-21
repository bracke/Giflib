with Giflib;
with Giflib.Decoding;
with Giflib.Limits;
with Giflib.Results;
with Giflib_Fuzz_Source;
with Project_Tools.Release_Checks;

package body Giflib_Fuzz_Harness is
   use type Giflib.Byte;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Image_Height;
   use type Giflib.Image_Width;

   procedure Verify_Stress_Seed
     (Storage : aliased Giflib.Streams.Byte_Array;
      Uniform : Boolean)
   is
      Source : aliased Giflib_Fuzz_Source.Prefix_Source
        (Storage'Access, Storage'Length);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Pixels : Giflib.Streams.Byte_Array (1 .. 4_096);
      Outcome : Giflib.Results.Result;

      procedure Require (Condition : Boolean; Message : String) is
      begin
         if not Condition then
            Project_Tools.Release_Checks.Fail
              ("giflib_fuzz: invalid handcrafted stress seed: " & Message);
         end if;
      end Require;
   begin
      Outcome := Giflib.Decoding.Initialize (Decoder);
      Require (Giflib.Results.Succeeded (Outcome), "initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Require
        (Giflib.Results.Succeeded (Outcome)
         and then Header.Width = 64
         and then Header.Height = 64,
         "header or dimensions changed");
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Require
        (Giflib.Results.Succeeded (Outcome)
         and then Event.Kind = Giflib.Decoding.Image_Event,
         "image event was not produced");
      Outcome := Giflib.Decoding.Decode_Indexed_Frame
        (Decoder, Pixels, Info);
      Require (Giflib.Results.Succeeded (Outcome), "image data was rejected");
      for Position in 0 .. 4_095 loop
         Require
           (Pixels (Pixels'First + Position) =
              Giflib.Byte
                (if Uniform then 0
                 else (Position + Position / 256) mod 256),
            "pixel" & Natural'Image (Position) & " differs");
      end loop;
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      Require
        (Giflib.Results.Succeeded (Outcome)
         and then Event.Kind = Giflib.Decoding.End_Event,
         "trailer was not reached");
   end Verify_Stress_Seed;

   procedure Exercise
     (Storage : aliased Giflib.Streams.Byte_Array;
      Length : Positive)
   is
      Source : aliased Giflib_Fuzz_Source.Prefix_Source
        (Storage'Access, Length);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Outcome : Giflib.Results.Result;
   begin
      Constraints.Max_Logical_Width := 64;
      Constraints.Max_Logical_Height := 64;
      Constraints.Max_Canvas_Pixels := 4_096;
      Constraints.Max_Canvas_Bytes := 16_384;
      Constraints.Max_Frame_Pixels := 4_096;
      Constraints.Max_Total_Decoded_Frame_Pixels := 16_384;
      Constraints.Max_Compressed_Bytes := 16_384;
      Constraints.Max_Extensions := 32;
      Constraints.Max_Per_Extension_Bytes := 4_096;
      Constraints.Max_Retained_Metadata_Bytes := 4_096;
      Constraints.Max_Allocation_Bytes := 65_536;
      Constraints.Max_LZW_Work := 65_536;
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Outcome := Giflib.Decoding.Initialize (Decoder, Options, Constraints);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         declare
            Canvas : Giflib.Streams.Byte_Array
              (1 .. Natural (Header.Width) * Natural (Header.Height) * 4);
            Info : Giflib.Decoding.Frame_Info;
         begin
            for Event_Count in 1 .. 64 loop
               Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
               exit when not Giflib.Results.Succeeded (Outcome)
                 or else Event.Kind = Giflib.Decoding.End_Event;
               if Event.Kind = Giflib.Decoding.Image_Event then
                  Outcome := Giflib.Decoding.Decode_Composited_Frame
                    (Decoder, Canvas, Info);
                  exit when not Giflib.Results.Succeeded (Outcome);
               end if;
            end loop;
         end;
      end if;
   end Exercise;
end Giflib_Fuzz_Harness;
