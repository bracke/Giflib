separate (Giflib.Testing.Test_Encoding)
procedure Enforces_Session_Encoding_Budgets (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Storage : aliased Giflib.Streams.Byte_Array := [for I in 1 .. 512 => 0];
   Destination : aliased Giflib.Streams.Fixed_Buffer_Destination (Storage'Access);
   Encoder : Giflib.Encoding.Encoder (Destination'Access);
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Frame : constant Giflib.Encoding.Frame_Info := (others => <>);
   Outcome : Giflib.Results.Result;

   procedure Start is
   begin
      Giflib.Streams.Open (Destination);
      Outcome := Giflib.Encoding.Initialize
        (Encoder, Constraints => Constraints);
      Giflib.Testing.Assertions.Require_Success (Outcome);
      Outcome := Giflib.Encoding.Define_Screen (Encoder, (others => <>));
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Encoding.Set_Global_Palette (Encoder, BW_Palette);
      end if;
   end Start;
begin
   Constraints.Max_Logical_Width := 1;
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize
     (Encoder, Constraints => Constraints);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Define_Screen
     (Encoder, (Width => 2, Height => 1, others => <>));
   Assert
     (Outcome.First_Error.Context.Limit = Giflib.Logical_Width_Limit
      and then not Outcome.First_Error.Context.Has_Frame,
      "screen-definition failure was attributed to a frame");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Frames := 1;
   Start;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [1]);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Frame_Count_Limit
           and then Outcome.First_Error.Context.Has_Frame
           and then Outcome.First_Error.Context.Frame = 1,
           "encoder frame-count budget was ignored");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Output_Bytes := 10;
   Start;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit,
           "encoder output-byte budget was ignored");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Output_Bytes := Giflib.Byte_Count'Last;
   Giflib.Streams.Open (Destination);
   Outcome := Giflib.Encoding.Initialize
     (Encoder, Constraints => Constraints);
   Giflib.Testing.Assertions.Require_Success (Outcome);
   Giflib.Encoding.Testing.Set_Bytes_Written
     (Encoder, Giflib.Byte_Count'Last);
   Outcome := Giflib.Encoding.Testing.Write_Raw (Encoder, [0]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Limit_Exceeded
      and then Outcome.First_Error.Context.Limit = Giflib.Output_Byte_Limit
      and then Outcome.First_Error.Context.Actual = Giflib.Byte_Count'Last,
      "overflowing output-byte diagnostic did not saturate");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Compressed_Bytes := 3;
   Start;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
   Assert (Giflib.Results.Succeeded (Outcome), "first compressed-budget frame failed");
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [1]);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Compressed_Byte_Limit,
           "cumulative compressed-byte budget was ignored");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Frame_Pixels := 0;
   Start;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Frame_Pixel_Limit,
           "encoder frame-pixel budget was ignored");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Start;
   Outcome := Giflib.Encoding.Add_Indexed_Frame
     (Encoder, Frame, Giflib.Encoding.Use_Global_Palette, (others => <>), [2]);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Palette_Index_Out_Of_Range
           and then Destination.Offset > 0,
           "indexed compression did not validate palette values in-stream");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Extensions := 0;
   Start;
   Outcome := Giflib.Encoding.Set_Loop_Count (Encoder, 0);
   Assert (Outcome.First_Error.Context.Limit = Giflib.Extension_Count_Limit,
           "loop extension escaped the extension-count budget");

   Giflib.Encoding.Finalize (Encoder);
   Start;
   declare
      Controlled : Giflib.Encoding.Frame_Info := Frame;
   begin
      Controlled.Control.Delay_CS := 1;
      Outcome := Giflib.Encoding.Add_Indexed_Frame
        (Encoder, Controlled, Giflib.Encoding.Use_Global_Palette, (others => <>), [0]);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Extension_Count_Limit,
              "graphic control escaped the extension-count budget");
   end;

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Start;
   Outcome := Giflib.Encoding.Add_Extension
     (Encoder,
      (Kind => Giflib.Metadata.Comment_Extension, Label => 16#FF#, others => <>),
      [1]);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Extension,
           "mismatched extension kind and label were accepted");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Start;
   Outcome := Giflib.Encoding.Add_Extension_Exact
     (Encoder,
      (Kind => Giflib.Metadata.Comment_Extension,
       Label => 16#FE#,
       others => <>),
      [1],
      [1, 1]);
   Assert
     (Outcome.First_Error.Code = Giflib.Errors.Invalid_Extension
      and then Destination.Offset = 0,
      "oversized exact-extension chunk list was traversed or emitted");

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Frame_Pixels := 0;
   Start;
   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => RGB'Access);
   begin
      Outcome := Giflib.Encoding.Add_Truecolor_Frame (Encoder, Frame, View);
      Assert (Outcome.First_Error.Context.Limit = Giflib.Frame_Pixel_Limit,
              "truecolor encoding escaped the frame-pixel budget");
   end;

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Frames := 0;
   Constraints.Max_Quantization_Work := 0;
   Start;
   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => RGB'Access);
   begin
      Outcome := Giflib.Encoding.Add_Truecolor_Frame (Encoder, Frame, View);
      Assert
        (Outcome.First_Error.Context.Limit = Giflib.Frame_Count_Limit,
         "truecolor quantization ran before shared frame preflight");
   end;

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Allocation_Bytes :=
     Giflib.Byte_Count (32_768 * (Natural'Size / 8));
   Start;
   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24, Width => 1, Height => 1, Stride => 3,
         Accessible_Bytes => 3, Data => RGB'Access);
   begin
      Outcome := Giflib.Encoding.Add_Truecolor_Frame (Encoder, Frame, View);
      Assert
        (Outcome.First_Error.Context.Limit = Giflib.Allocation_Byte_Limit
         and then Outcome.First_Error.Context.Expected
           = Constraints.Max_Allocation_Bytes
         and then Outcome.First_Error.Context.Actual
           > Constraints.Max_Allocation_Bytes,
         "truecolor workspace allocations did not share the session budget");
   end;

   Giflib.Encoding.Finalize (Encoder);
   Constraints := Giflib.Limits.Default_Limits;
   Constraints.Max_Frame_Pixels := 4_294_836_225;
   Constraints.Max_Allocation_Bytes := 4_294_836_225;
   Start;
   declare
      RGB : aliased constant Giflib.Streams.Byte_Array := [0, 0, 0];
      Huge_Frame : constant Giflib.Encoding.Frame_Info :=
        (Width => 65_535, Height => 65_535, others => <>);
      Invalid_View : constant Giflib.Images.Image_View :=
        (Format => Giflib.RGB_24,
         Width => 65_535,
         Height => 65_535,
         Stride => 196_605,
         Accessible_Bytes => 3,
         Data => RGB'Access);
   begin
      Outcome := Giflib.Encoding.Add_Truecolor_Frame
        (Encoder, Huge_Frame, Invalid_View);
      Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Dimensions,
              "malformed truecolor view was allocated before validation");
   end;
end Enforces_Session_Encoding_Budgets;

