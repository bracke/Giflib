with Giflib.Frames;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;

package Giflib.Optimization is
   pragma Preelaborate;

   type Optimization_Action is (Keep_Full_Frame, Trim_To_Rectangle, Merge_With_Previous);

   type Optimization_Options is record
      Trim_Unchanged_Border : Boolean := True;
      Make_Interior_Unchanged_Transparent : Boolean := True;
      Transparent_Index : Palette_Index := 0;
   end record;

   Default_Options : constant Optimization_Options := (others => <>);

   type Frame_Analysis (Action : Optimization_Action := Keep_Full_Frame) is record
      case Action is
         when Keep_Full_Frame =>
            Full_Width : Image_Width := Image_Width'First;
            Full_Height : Image_Height := Image_Height'First;
         when Trim_To_Rectangle =>
            Left : Coordinate := 0;
            Top : Coordinate := 0;
            Width : Image_Width := Image_Width'First;
            Height : Image_Height := Image_Height'First;
            Requires_Transparency : Boolean := False;
         when Merge_With_Previous =>
            Merged_Delay : Delay_Centiseconds := 0;
      end case;
   end record;

   --  Previous and Current are full-canvas indexed renderings using equivalent
   --  palettes. Optimization is deliberately conservative: disposal 2/3,
   --  user-input controls, existing transparency, or unequal palettes retain
   --  the complete frame.
   function Analyze_Indexed
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Previous_Control : Frames.Graphic_Control;
      Current_Control : Frames.Graphic_Control;
      Palettes_Are_Equivalent : Boolean;
      Item : out Frame_Analysis;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;

   --  Produces the tight row-major rectangle described by Item. When requested,
   --  pixels equal to Previous inside the rectangle become Transparent_Index.
   --  Analysis suppresses transparency when that index is also needed by a
   --  changed pixel. Extraction repeats that safety check for its supplied
   --  options, preserving rendered equivalence even when callers change them.
   function Extract_Indexed_Rectangle
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height;
      Item : Frame_Analysis;
      Output : out Streams.Byte_Array;
      Options : Optimization_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result;
end Giflib.Optimization;
