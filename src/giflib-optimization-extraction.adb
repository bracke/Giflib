with Giflib.Errors;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Work_Budgets;
with Giflib.Optimization.Rectangle_Walker;

package body Giflib.Optimization.Extraction is
   package Walker renames Giflib.Optimization.Rectangle_Walker;

   function Extract_Indexed_Rectangle
     (Previous : Streams.Byte_Array;
      Current : Streams.Byte_Array;
      Canvas_Width : Image_Width;
      Canvas_Height : Image_Height;
      Item : Frame_Analysis;
      Output : out Streams.Byte_Array;
      Options : Optimization_Options;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Canvas_Pixels : constant Byte_Count :=
        Internal.Geometry_Arithmetic.Area (Canvas_Width, Canvas_Height);
      Rectangle_Pixels : constant Byte_Count :=
        (if Item.Action = Trim_To_Rectangle
         then Internal.Geometry_Arithmetic.Area (Item.Width, Item.Height)
         else 0);
      Work : Internal.Work_Budgets.Meter
        (Constraints.Max_Optimization_Work);
      Output_Position : Natural := 0;
      Use_Transparency : Boolean :=
        Item.Action = Trim_To_Rectangle and then Item.Requires_Transparency;
      Outcome : Results.Result;

      function Check_Transparent_Conflict
        (X : Natural; Y : Natural; Position : Natural)
         return Walker.Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         if Previous (Previous'First + Position) /=
           Current (Current'First + Position)
           and then Current (Current'First + Position) =
             Byte (Options.Transparent_Index)
         then
            Use_Transparency := False;
            return Walker.Stop_Visit;
         end if;
         return Walker.Continue_Visit;
      end Check_Transparent_Conflict;

      function Write_Pixel
        (X : Natural; Y : Natural; Position : Natural)
         return Walker.Visit_Action
      is
         pragma Unreferenced (X, Y);
      begin
         Output (Output'First + Output_Position) :=
           (if Use_Transparency
              and then Previous (Previous'First + Position) =
                Current (Current'First + Position)
            then Byte (Options.Transparent_Index)
            else Current (Current'First + Position));
         Output_Position := Output_Position + 1;
         return Walker.Continue_Visit;
      end Write_Pixel;

      function Walk_Conflicts is new Walker.Walk (Check_Transparent_Conflict);
      function Walk_Output is new Walker.Walk (Write_Pixel);
   begin
      if Item.Action /= Trim_To_Rectangle
        or else Natural (Item.Left) + Natural (Item.Width) >
          Natural (Canvas_Width)
        or else Natural (Item.Top) + Natural (Item.Height) >
          Natural (Canvas_Height)
      then
         return Results.Failure (Errors.Make (Errors.Invalid_Dimensions));
      elsif Byte_Count (Previous'Length) /= Canvas_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Canvas_Pixels,
                Actual => Byte_Count (Previous'Length), others => <>)));
      elsif Byte_Count (Current'Length) /= Canvas_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Canvas_Pixels,
                Actual => Byte_Count (Current'Length), others => <>)));
      elsif Byte_Count (Output'Length) /= Rectangle_Pixels then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Rectangle_Pixels,
                Actual => Byte_Count (Output'Length), others => <>)));
      end if;
      if Use_Transparency then
         Outcome := Walk_Conflicts
           (Work, Natural (Item.Left), Natural (Item.Top),
            Natural (Item.Width), Natural (Item.Height), Canvas_Width);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;
      return Walk_Output
        (Work, Natural (Item.Left), Natural (Item.Top),
         Natural (Item.Width), Natural (Item.Height), Canvas_Width);
   end Extract_Indexed_Rectangle;
end Giflib.Optimization.Extraction;
