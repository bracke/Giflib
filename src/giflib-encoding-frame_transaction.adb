with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Resource_Management;
with Giflib.Encoding.Session_Transitions;
with Giflib.Encoding.Wire_Output;
with Giflib.Internal.Container_Writer;

package body Giflib.Encoding.Frame_Transaction is
   use type Frames.Graphic_Control;

   function Commit_Prefix
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Data : Frame_Preparation.Prepared_Frame_Request)
      return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Resource_Management.Ensure_LZW_Workspace (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Outcome := Write_Header (Object);
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      if Info.Control /= Frames.Default_Control then
         Outcome := Wire_Output.Write
           (Object, Internal.Container_Writer.Graphic_Control (Info.Control));
         if not Results.Succeeded (Outcome) then
            return Failure_Handling.Fail_Frame_Request
              (Object, Outcome.First_Error);
         end if;
         Session_Transitions.Record_Extension (Object);
      end if;
      Outcome := Wire_Output.Write
        (Object,
         Internal.Container_Writer.Image_Descriptor
           (Left => Info.Left, Top => Info.Top,
            Width => Info.Width, Height => Info.Height,
            Local_Palette =>
              (if Palette.Selection = Use_Local_Palette
               then (Present => True,
                     Length => Internal.Container_Writer.Palette_Length
                       (Data.Effective.Length),
                     Sorted => False)
               else Internal.Container_Writer.No_Palette),
            Interlaced => Info.Interlaced));
      if Results.Succeeded (Outcome)
        and then Palette.Selection = Use_Local_Palette
      then
         Outcome := Wire_Output.Write_Color_Table (Object, Data.Effective);
      end if;
      if not Results.Succeeded (Outcome) then
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Outcome := Wire_Output.Write (Object, [1 => Data.Minimum]);
      return
        (if Results.Succeeded (Outcome)
         then Results.Success
         else Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error));
   end Commit_Prefix;

   function Complete
     (Object : in out Encoder;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count) return Results.Result is
   begin
      if not Results.Succeeded (Outcome) then
         Session_Transitions.Record_Output (Object, Compressed, Wire_Bytes);
         return Failure_Handling.Fail_Frame_Request (Object, Outcome.First_Error);
      end if;
      Session_Transitions.Complete_Frame (Object, Compressed, Wire_Bytes);
      return Results.Success;
   end Complete;
end Giflib.Encoding.Frame_Transaction;
