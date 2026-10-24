with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;

procedure Giflib_Generate_Fixtures is
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   Root : constant String :=
     Files.Find_Root_Upward (Ada.Directories.Current_Directory, "giflib.gpr");
   Output_Directory : constant String :=
     (if Ada.Command_Line.Argument_Count = 1
      then Ada.Command_Line.Argument (1)
      else Files.Join (Root, "tests/fixtures/generated"));
   Convert : constant String := Processes.Locate_Command ("convert");

   procedure Write_PPM (Path : String; Width, Height, Pattern : Positive) is
      File : Ada.Text_IO.File_Type;
      R, G, B : Natural;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "P3");
      Ada.Text_IO.Put_Line (File, Natural'Image (Width) & Natural'Image (Height));
      Ada.Text_IO.Put_Line (File, "255");
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            case Pattern is
               when 1 =>
                  case (Y * Width + X) mod 4 is
                     when 0 => R := 0; G := 0; B := 0;
                     when 1 => R := 255; G := 0; B := 0;
                     when 2 => R := 0; G := 255; B := 0;
                     when others => R := 0; G := 0; B := 255;
                  end case;
               when 2 =>
                  if X = 0 then R := 255; G := 0; B := 0;
                  elsif X = 1 then R := 0; G := 255; B := 0;
                  else R := 255; G := 0; B := 0;
                  end if;
               when 3 =>
                  if X = 0 then R := 0; G := 0; B := 255;
                  elsif X = 1 then R := 0; G := 255; B := 0;
                  else R := 255; G := 0; B := 0;
                  end if;
               when 4 =>
                  if X < 2 then R := 0; G := 0; B := 255;
                  else R := 255; G := 0; B := 0;
                  end if;
               when others =>
                  R := X * 255 / Natural'Max (1, Width - 1);
                  G := Y * 255 / Natural'Max (1, Height - 1);
                  B := (X * 17 + Y * 29) mod 256;
            end case;
            Ada.Text_IO.Put
              (File, Natural'Image (R) & Natural'Image (G) & Natural'Image (B) & " ");
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);
   end Write_PPM;

   Still_PPM : constant String := Files.Join (Output_Directory, "indexed.ppm");
   Frame_0 : constant String := Files.Join (Output_Directory, "frame-0.ppm");
   Frame_1 : constant String := Files.Join (Output_Directory, "frame-1.ppm");
   Frame_2 : constant String := Files.Join (Output_Directory, "frame-2.ppm");
   Interlace_PPM : constant String := Files.Join (Output_Directory, "interlaced.ppm");
begin
   if Root = "" then
      Project_Tools.Release_Checks.Fail
        ("giflib_generate_fixtures: run from within the giflib source tree");
   elsif Ada.Command_Line.Argument_Count > 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_generate_fixtures [output-directory]");
   end if;
   Processes.Require_Command
     ("convert", "giflib_generate_fixtures: ImageMagick convert is required");

   Ada.Directories.Create_Path (Output_Directory);
   Write_PPM (Still_PPM, 5, 3, 1);
   Write_PPM (Frame_0, 3, 1, 2);
   Write_PPM (Frame_1, 3, 1, 3);
   Write_PPM (Frame_2, 3, 1, 4);
   Write_PPM (Interlace_PPM, 9, 9, 5);

   Processes.Run
     ("independent indexed fixture generation",
      Root,
      Convert,
      Processes.Arguments
        ([Processes.Argument (Still_PPM), Processes.Argument ("-colors"),
          Processes.Argument ("4"),
          Processes.Argument (Files.Join (Output_Directory, "imagemagick-indexed.gif"))]));
   Processes.Run
     ("independent animation fixture generation",
      Root,
      Convert,
      Processes.Arguments
        ([Processes.Argument ("-delay"), Processes.Argument ("0"),
          Processes.Argument ("-dispose"), Processes.Argument ("none"),
          Processes.Argument (Frame_0), Processes.Argument ("-delay"),
          Processes.Argument ("7"), Processes.Argument ("-dispose"),
          Processes.Argument ("background"), Processes.Argument (Frame_1),
          Processes.Argument ("-delay"), Processes.Argument ("2"),
          Processes.Argument ("-dispose"), Processes.Argument ("previous"),
          Processes.Argument (Frame_2), Processes.Argument ("-loop"),
          Processes.Argument ("2"),
          Processes.Argument (Files.Join (Output_Directory, "imagemagick-animation.gif"))]));
   Processes.Run
     ("independent interlaced fixture generation",
      Root,
      Convert,
      Processes.Arguments
        ([Processes.Argument (Interlace_PPM), Processes.Argument ("-colors"),
          Processes.Argument ("16"), Processes.Argument ("-interlace"),
          Processes.Argument ("GIF"),
          Processes.Argument (Files.Join (Output_Directory, "imagemagick-interlaced.gif"))]));

   Files.Delete_File_If_Present (Still_PPM);
   Files.Delete_File_If_Present (Frame_0);
   Files.Delete_File_If_Present (Frame_1);
   Files.Delete_File_If_Present (Frame_2);
   Files.Delete_File_If_Present (Interlace_PPM);
   Ada.Text_IO.Put_Line ("Ada fixture generator completed: " & Output_Directory);
exception
   when others =>
      Files.Delete_File_If_Present (Still_PPM);
      Files.Delete_File_If_Present (Frame_0);
      Files.Delete_File_If_Present (Frame_1);
      Files.Delete_File_If_Present (Frame_2);
      Files.Delete_File_If_Present (Interlace_PPM);
      raise;
end Giflib_Generate_Fixtures;
