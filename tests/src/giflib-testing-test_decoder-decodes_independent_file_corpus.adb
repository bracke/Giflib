separate (Giflib.Testing.Test_Decoder)
procedure Decodes_Independent_File_Corpus (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Root : constant String := Project_Tools.Files.Find_Root_Upward
     (Ada.Directories.Current_Directory, "giflib.gpr");
   Indexed_Expected : constant Giflib.Streams.Byte_Array :=
     [0, 0, 0, 255, 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
      0, 0, 0, 255,
      255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 255,
      255, 0, 0, 255,
      0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 255, 255, 0, 0, 255,
      0, 255, 0, 255];
   Animation_Expected : constant Giflib.Streams.Byte_Array :=
     [255, 0, 0, 255, 0, 255, 0, 255, 255, 0, 0, 255,
      0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255,
      0, 0, 255, 255, 0, 0, 255, 255, 255, 0, 0, 255];
   Interlaced_Expected : constant Giflib.Streams.Byte_Array :=
     [27, 22, 35, 255, 27, 22, 35, 255, 27, 22, 35, 255,
      114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
      183, 8, 105, 255, 183, 8, 105, 255, 183, 8, 105, 255,
      27, 22, 35, 255, 27, 22, 35, 255, 27, 22, 35, 255,
      114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
      183, 8, 105, 255, 213, 77, 184, 255, 213, 77, 184, 255,
      27, 22, 35, 255, 40, 77, 92, 255, 40, 77, 92, 255,
      114, 38, 96, 255, 114, 38, 96, 255, 183, 8, 105, 255,
      213, 77, 184, 255, 213, 77, 184, 255, 213, 77, 184, 255,
      40, 77, 92, 255, 40, 77, 92, 255, 40, 77, 92, 255,
      111, 111, 161, 255, 111, 111, 161, 255, 111, 111, 161, 255,
      213, 77, 184, 255, 213, 77, 184, 255, 213, 77, 184, 255,
      47, 127, 142, 255, 47, 127, 142, 255, 47, 127, 142, 255,
      111, 111, 161, 255, 111, 111, 161, 255, 175, 159, 239, 255,
      175, 159, 239, 255, 175, 159, 239, 255, 175, 159, 239, 255,
      25, 172, 170, 255, 25, 172, 170, 255, 25, 172, 170, 255,
      111, 175, 219, 255, 111, 175, 219, 255, 175, 159, 239, 255,
      175, 159, 239, 255, 239, 175, 31, 255, 239, 175, 31, 255,
      25, 172, 170, 255, 25, 172, 170, 255, 79, 207, 231, 255,
      111, 175, 219, 255, 111, 175, 219, 255, 175, 223, 41, 255,
      175, 223, 41, 255, 239, 175, 31, 255, 239, 175, 31, 255,
      25, 236, 228, 255, 25, 236, 228, 255, 79, 207, 231, 255,
      79, 207, 231, 255, 103, 247, 24, 255, 175, 223, 41, 255,
      175, 223, 41, 255, 239, 239, 89, 255, 239, 239, 89, 255,
      25, 236, 228, 255, 25, 236, 228, 255, 103, 247, 24, 255,
      103, 247, 24, 255, 103, 247, 24, 255, 175, 223, 41, 255,
      175, 223, 41, 255, 239, 239, 89, 255, 239, 239, 89, 255];
   procedure Check_Composited
     (Relative_Path : String;
      Expected_Width : Giflib.Image_Width;
      Expected_Height : Giflib.Image_Height;
      Expected : Giflib.Streams.Byte_Array)
   is
      Raw : constant String := Project_Tools.Files.Read_Raw_File
        (Project_Tools.Files.Join (Root, Relative_Path));
      Data : aliased Giflib.Streams.Byte_Array := [for I in 1 .. Raw'Length => 0];
      Source : aliased Giflib.Streams.Memory_Source (Data'Access);
      Decoder : Giflib.Decoding.Decoder (Source'Access);
      Options : Giflib.Decoding.Decode_Options := Giflib.Decoding.Default_Options;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Canvas : Giflib.Streams.Byte_Array
        (1 .. Natural (Expected_Width) * Natural (Expected_Height) * 4);
      Outcome : Giflib.Results.Result;
      Position : Natural := Expected'First;
   begin
      for I in Raw'Range loop
         Data (I - Raw'First + 1) := Giflib.Byte (Character'Pos (Raw (I)));
      end loop;
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Giflib.Streams.Open (Source, Max_Transfer => 3);
      Outcome := Giflib.Decoding.Initialize (Decoder, Options);
      Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " initialization failed");
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      Assert (Giflib.Results.Succeeded (Outcome)
              and then Header.Width = Expected_Width
              and then Header.Height = Expected_Height,
              Relative_Path & " header changed");
      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " event decode failed");
         exit when Event.Kind = Giflib.Decoding.End_Event;
         if Event.Kind = Giflib.Decoding.Image_Event then
            Assert (Position + Canvas'Length - 1 <= Expected'Last,
                    Relative_Path & " produced too many frames");
            Outcome := Giflib.Decoding.Decode_Composited_Frame (Decoder, Canvas, Info);
            Assert (Giflib.Results.Succeeded (Outcome), Relative_Path & " frame decode failed");
            Assert (Canvas = Expected (Position .. Position + Canvas'Length - 1),
                    Relative_Path & " composited pixels changed");
            Position := Position + Canvas'Length;
         end if;
      end loop;
      Assert (Position = Expected'Last + 1, Relative_Path & " produced too few frames");
      Giflib.Decoding.Finalize (Decoder);
   end Check_Composited;
begin
   Assert (Root /= "", "could not locate repository root for independent fixtures");
   Check_Composited
     ("tests/fixtures/generated/imagemagick-indexed.gif", 5, 3, Indexed_Expected);
   Check_Composited
     ("tests/fixtures/generated/imagemagick-animation.gif", 3, 1, Animation_Expected);
   Check_Composited
     ("tests/fixtures/generated/imagemagick-interlaced.gif", 9, 9,
      Interlaced_Expected);
end Decodes_Independent_File_Corpus;
