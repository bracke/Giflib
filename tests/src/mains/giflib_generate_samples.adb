with Ada.Command_Line;
with Ada.Directories;

with Giflib;
with Giflib.Encoding;
with Giflib.Images;
with Giflib.Palettes;
with Giflib.Quantization;
with Giflib.Results;
with Giflib.Streams;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

procedure Giflib_Generate_Samples is
   Output_Directory : constant String :=
     (if Ada.Command_Line.Argument_Count = 1
      then Ada.Command_Line.Argument (1)
      else "artifacts");

   procedure Require (Outcome : Giflib.Results.Result; Operation : String) is
   begin
      if not Giflib.Results.Succeeded (Outcome) then
         Project_Tools.Release_Checks.Fail
           ("giflib_generate_samples: " & Operation);
      end if;
   end Require;

   procedure Save
     (Path : String;
      Data : Giflib.Streams.Byte_Array;
      Length : Natural)
   is
      Raw : String (1 .. Length);
   begin
      for I in 1 .. Length loop
         Raw (I) := Character'Val (Data (Data'First + I - 1));
      end loop;
      Project_Tools.Files.Write_Raw_File (Path, Raw);
   end Save;

   function Palette return Giflib.Palettes.Palette is
      Item : Giflib.Palettes.Palette;
   begin
      Item.Length := 4;
      Item.Colors (0) := (0, 0, 0);
      Item.Colors (1) := (255, 0, 0);
      Item.Colors (2) := (0, 255, 0);
      Item.Colors (3) := (0, 0, 255);
      return Item;
   end Palette;

   procedure Generate_Still is
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 4_096 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Outcome : Giflib.Results.Result;
   begin
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 5);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Require (Outcome, "initialize still");
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 3, Height => 2, others => <>));
      Require (Outcome, "define still screen");
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, Palette);
      Require (Outcome, "set still palette");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder,
         (Left => 0, Top => 0, Width => 3, Height => 2, Interlaced => True, others => <>),
         Giflib.Encoding.Use_Global_Palette,
         (others => <>),
         [1, 2, 3, 3, 2, 1]);
      Require (Outcome, "encode still frame");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Require (Outcome, "finish still");
      Save (Output_Directory & "/giflib-still.gif", Storage, Natural (Destination.Offset));
   end Generate_Still;

   procedure Generate_Animation is
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 8_192 => 0];
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      First : Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 2, Height => 1, others => <>);
      Second : Giflib.Encoding.Frame_Info :=
        (Left => 0, Top => 0, Width => 1, Height => 1, others => <>);
      Outcome : Giflib.Results.Result;
   begin
      First.Control := (Disposal => 1, Delay_CS => 3, others => <>);
      Second.Control := (Disposal => 2, Delay_CS => 0, others => <>);
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 7);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Require (Outcome, "initialize animation");
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (Width => 2, Height => 1, others => <>));
      Require (Outcome, "define animation screen");
      Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, Palette);
      Require (Outcome, "set animation palette");
      Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
      Require (Outcome, "set animation loop");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, First, Giflib.Encoding.Use_Global_Palette, (others => <>), [1, 2]);
      Require (Outcome, "encode animation frame 1");
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Second, Giflib.Encoding.Use_Global_Palette, (others => <>), [3]);
      Require (Outcome, "encode animation frame 2");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Require (Outcome, "finish animation");
      Save (Output_Directory & "/giflib-animation.gif", Storage, Natural (Destination.Offset));
   end Generate_Animation;

   procedure Generate_Truecolor is
      RGB : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 17 * 17 * 3 => 0];
      Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 16_384 => 0];
      View : Giflib.Images.Image_View;
      Destination : aliased Giflib.Streams.Fixed_Buffer_Destination;
      Encoder : Giflib.Encoding.Encoder;
      Options : Giflib.Quantization.Quantize_Options := Giflib.Quantization.Default_Options;
      Outcome : Giflib.Results.Result;
      Position : Natural := RGB'First;
   begin
      for Y in 0 .. 16 loop
         for X in 0 .. 16 loop
            RGB (Position) := Giflib.Byte (X * 15);
            RGB (Position + 1) := Giflib.Byte (Y * 15);
            RGB (Position + 2) := Giflib.Byte ((X * 17 + Y) mod 256);
            Position := Position + 3;
         end loop;
      end loop;
      View :=
        (Format => Giflib.RGB_24, Width => 17, Height => 17, Stride => 51,
         Accessible_Bytes => RGB'Length, Data => RGB'Unchecked_Access);
      Options.Maximum_Colors := 16;
      Options.Dither := Giflib.Quantization.Floyd_Steinberg;
      Giflib.Streams.Open (Destination, Storage'Unchecked_Access, Max_Transfer => 11);
      Outcome := Giflib.Encoding.Initialize (Encoder, Destination'Unchecked_Access);
      Require (Outcome, "initialize truecolor");
      Outcome := Giflib.Encoding.Define_Screen
        (Encoder, (Width => 17, Height => 17, others => <>));
      Require (Outcome, "define truecolor screen");
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Encoder, (Width => 17, Height => 17, others => <>), View, Options);
      Require (Outcome, "encode truecolor frame");
      Outcome := Giflib.Encoding.Finish (Encoder);
      Require (Outcome, "finish truecolor");
      Save (Output_Directory & "/giflib-truecolor.gif", Storage, Natural (Destination.Offset));
   end Generate_Truecolor;
begin
   if Ada.Command_Line.Argument_Count > 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_generate_samples [output-directory]");
   end if;
   Ada.Directories.Create_Path (Output_Directory);
   Generate_Still;
   Generate_Animation;
   Generate_Truecolor;
exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      raise;
end Giflib_Generate_Samples;
