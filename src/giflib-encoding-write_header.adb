with Giflib.Encoding.Wire_Output;
with Giflib.Internal.Container_Writer;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Loop_Extensions;

separate (Giflib.Encoding)
function Write_Header (Object : in out Encoder) return Results.Result is
   Outcome : Results.Result;
begin
   if Object.Current_State in Header_Committed | Accepting_Frames then
      return Results.Success;
   end if;
   if Object.Options.Version = Force_GIF87a
     and then Object.Loop_Data.State /= Animations.No_Loop_Extension
   then
      return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
   end if;
   Outcome := Wire_Output.Write
     (Object,
      Internal.Container_Writer.Signature
        (if Object.Options.Version = Force_GIF87a
         then GIF87a else GIF89a));
   if Results.Succeeded (Outcome) then
      Outcome := Wire_Output.Write
        (Object,
         Internal.Container_Writer.Logical_Screen
           (Width => Object.Screen.Width,
            Height => Object.Screen.Height,
            Color_Resolution => Object.Screen.Color_Resolution,
            Global_Palette =>
              (if Object.Global_Palette.Present
               then (Present => True,
                     Length => Internal.Container_Writer.Palette_Length
                       (Object.Global_Palette.Value.Length),
                     Sorted => False)
               else Internal.Container_Writer.No_Palette),
            Background_Index => Object.Screen.Background_Index,
            Pixel_Aspect_Ratio => Object.Screen.Pixel_Aspect_Ratio));
   end if;
   if Results.Succeeded (Outcome) and then Object.Global_Palette.Present then
      Outcome := Wire_Output.Write_Color_Table (Object, Object.Global_Palette.Value);
   end if;
   if Results.Succeeded (Outcome)
     and then Object.Loop_Data.State /= Animations.No_Loop_Extension
   then
      if not Request_Validation.Has_Extension_Room (Object, 1) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               Internal.Diagnostics.At_Destination
                 (Object.Output.all,
                  (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                   Actual => Byte_Count (Object.Extensions_Written) + 1,
                   Limit => Extension_Count_Limit,
                   others => <>))));
      end if;
      Outcome := Wire_Output.Write
        (Object,
         Internal.Loop_Extensions.Encode_Netscape
           (Animations.Raw_Count (Object.Loop_Data)));
   end if;
   if Results.Succeeded (Outcome) then
      Session_Transitions.Commit_Header
        (Object,
         Loop_Extension_Written =>
           Object.Loop_Data.State /= Animations.No_Loop_Extension);
   end if;
   return Outcome;
end Write_Header;
