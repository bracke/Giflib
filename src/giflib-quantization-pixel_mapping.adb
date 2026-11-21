with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Mapping;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Quantization_Storage.Dither_Operations;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Quantization.Workspace_Operations;

package body Giflib.Quantization.Pixel_Mapping is
   package Buffer_Arithmetic renames
     Internal.Quantization_Buffer_Arithmetic;
   package Cache renames
     Internal.Quantization_Storage.Cache_Operations;
   package Dither renames
     Internal.Quantization_Storage.Dither_Operations;
   package Mapping renames Internal.Quantization_Mapping;
   package Outcomes renames Internal.Quantization_Storage.Outcomes;
   package Pixels renames Internal.Quantization_Pixels;
   package Workspace_Service renames Workspace_Operations;
   use type Outcomes.Budgeted_Status;
   use type Outcomes.Storage_Status;
   use type Mapping.Find_Status;

   type Pixel_Status is (Pixel_Ready, Pixel_Invariant_Failure);
   Cache_Observation_Limit : constant := 4_096;
   Cache_Recovery_Observation_Limit : constant := 256;
   Cache_Disable_Hit_Divisor : constant := 4;
   Cache_Recovery_Hit_Divisor : constant := 8;
   type Cache_Mode is (Cache_Enabled, Cache_Cooldown, Cache_Recovery);
   type Cache_Policy is record
      Mode : Cache_Mode := Cache_Enabled;
      Samples : Natural range 0 .. Cache_Observation_Limit := 0;
      Misses : Natural range 0 .. Cache_Observation_Limit := 0;
      Cooldown : Natural range 0 .. Cache_Observation_Limit := 0;
      Has_Hint : Boolean := False;
      Last_Chosen : Palette_Index := 0;
   end record;

   function Uses_Cache (Policy : Cache_Policy) return Boolean is
     (Policy.Mode /= Cache_Cooldown);
   pragma Inline_Always (Uses_Cache);

   procedure Observe_Cache
     (Policy : in out Cache_Policy;
      Hit : Boolean) is
   begin
      if Policy.Mode = Cache_Cooldown then
         if Policy.Cooldown > 1 then
            Policy.Cooldown := Policy.Cooldown - 1;
         else
            Policy.Mode := Cache_Recovery;
            Policy.Cooldown := 0;
            Policy.Samples := 0;
            Policy.Misses := 0;
         end if;
         return;
      end if;
      Policy.Samples := Policy.Samples + 1;
      if not Hit then
         Policy.Misses := Policy.Misses + 1;
      end if;
      if Policy.Samples =
        (if Policy.Mode = Cache_Recovery
         then Cache_Recovery_Observation_Limit
         else Cache_Observation_Limit)
      then
         declare
            Divisor : constant Positive :=
              (if Policy.Mode = Cache_Recovery
               then Cache_Recovery_Hit_Divisor
               else Cache_Disable_Hit_Divisor);
         begin
            if (Policy.Samples - Policy.Misses) * Divisor < Policy.Samples
            then
               Policy.Mode := Cache_Cooldown;
               Policy.Cooldown := Cache_Observation_Limit;
            else
               Policy.Mode := Cache_Enabled;
            end if;
            Policy.Samples := 0;
            Policy.Misses := 0;
         end;
      end if;
   end Observe_Cache;

   function Prepare_Workspace
     (Context : in out Workspace;
      Width : Image_Width;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter;
      Use_Dither : Boolean) return Results.Result
   is
      Outcome : Results.Result;
      Budgeted : Outcomes.Budgeted_Status;
   begin
      Outcome := Workspace_Service.Ensure_Nearest_Cache
        (Context, Constraints);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Budgeted := Cache.Reset (Context.Resources, Work);
      if Budgeted = Outcomes.Budgeted_Work_Limit then
         return Workspace_Service.Work_Failure (Work);
      elsif Budgeted /= Outcomes.Budgeted_Ready then
         return Workspace_Service.Invariant_Failure;
      end if;
      if Use_Dither then
         Outcome := Workspace_Service.Ensure_Error_Buffer
           (Context, Width, Constraints);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Budgeted := Dither.Reset
           (Context.Resources,
            Buffer_Arithmetic.Error_Buffer_Length (Width),
            Work);
         if Budgeted = Outcomes.Budgeted_Work_Limit then
            return Workspace_Service.Work_Failure (Work);
         elsif Budgeted /= Outcomes.Budgeted_Ready then
            return Workspace_Service.Invariant_Failure;
         end if;
      end if;
      return Results.Success;
   end Prepare_Workspace;

   function Map_Pixel
     (Cache_State : in out Cache.Cache_State;
      Current_Epoch : Cache.Epoch;
      Errors : in out Dither.Error_State;
      Pixel : Pixels.Source_Pixel;
      Transparent : Boolean;
      X : Natural;
      Output_Index : Natural;
      Current_Group : Buffer_Arithmetic.Group_Index;
      Next_Group : Buffer_Arithmetic.Group_Index;
      Span : Buffer_Arithmetic.Error_Span;
      Indexed_Pixels : in out Streams.Byte_Array;
      Prepared : Palette_Building.Prepared_Palette;
      Search : Mapping.Search_Index;
      Policy : in out Cache_Policy;
      Work_Used : in out Byte_Count;
      Use_Dither : Boolean) return Pixel_Status
   is
      Adjusted : Palettes.RGB_Color;
      Chosen : Palette_Index;
      Find_Outcome : Mapping.Find_Status;
      Pixel_Work : Byte_Count;
      Cache_Hit : Boolean;
   begin
      if Transparent then
         Indexed_Pixels (Indexed_Pixels'First + Output_Index) :=
           Byte (Prepared.Transparent_Index);
         if Use_Dither then
            Dither.Clear_Transparent_Validated
              (Errors, Current_Group, X, Span);
         end if;
         return Pixel_Ready;
      end if;

      Adjusted := Pixel.Color;
      if Use_Dither then
         Adjusted := Dither.Adjust_Validated
           (Errors, Pixel.Color, Current_Group, X, Span);
      end if;
      Find_Outcome := Mapping.Find
        (Cache_State, Current_Epoch, Adjusted, Search, Uses_Cache (Policy),
         Policy.Has_Hint, Policy.Last_Chosen,
         Chosen, Cache_Hit, Pixel_Work);
      if Find_Outcome /= Mapping.Find_Ready then
         return Pixel_Invariant_Failure;
      end if;
      Observe_Cache (Policy, Cache_Hit);
      Policy.Has_Hint := True;
      Policy.Last_Chosen := Chosen;
      Work_Used := Work_Used + Pixel_Work;
      Indexed_Pixels (Indexed_Pixels'First + Output_Index) := Byte (Chosen);
      if Use_Dither then
         Dither.Diffuse_Validated
           (Errors, Current_Group, Next_Group, X, Span,
            Adjusted, Prepared.Value.Colors (Chosen));
      end if;
      return Pixel_Ready;
   end Map_Pixel;

   function Map_Row
     (Cache_State : in out Cache.Cache_State;
      Current_Epoch : Cache.Epoch;
      Errors : in out Dither.Error_State;
      Source : Images.Image_View;
      Y : Natural;
      Indexed_Pixels : in out Streams.Byte_Array;
      Prepared : Palette_Building.Prepared_Palette;
      Search : Mapping.Search_Index;
      Options : Quantize_Options;
      Policy : in out Cache_Policy;
      Work : in out Internal.Work_Budgets.Meter;
      Use_Dither : Boolean) return Results.Result
   is
      Span : constant Buffer_Arithmetic.Error_Span :=
        Buffer_Arithmetic.Span_Of (Source.Width);
      Current_Group : constant Buffer_Arithmetic.Group_Index :=
        (if Y mod 2 = 0 then 0 else 1);
      Next_Group : constant Buffer_Arithmetic.Group_Index :=
        (if Y mod 2 = 0 then 1 else 0);
      Row_Start : constant Natural := Y * Natural (Source.Width);
      Pixel_Outcome : Pixel_Status;
      Status : Outcomes.Storage_Status;
      Accepted : Boolean;
      Nearest_Work : Byte_Count := 0;
      Pixel : Pixels.Source_Pixel;
      Position : Positive := Pixels.Row_Start (Source, Y);

      generic
         with function Read
           (Source : Images.Image_View;
            Position : Positive) return Pixels.Source_Pixel;
         Bytes_Per_Pixel : Positive;
         Has_Alpha : Boolean;
      procedure Map_Formatted_Row;

      procedure Map_Formatted_Row is
      begin
         for X in 0 .. Natural (Source.Width) - 1 loop
            Pixel := Read (Source, Position);
            Pixel_Outcome := Map_Pixel
              (Cache_State, Current_Epoch, Errors, Pixel,
               Has_Alpha
                 and then Options.Transparency.Enabled
                 and then Pixel.Alpha <= Options.Transparency.Alpha_Threshold,
               X, Row_Start + X, Current_Group, Next_Group, Span,
               Indexed_Pixels, Prepared, Search, Policy, Nearest_Work,
               Use_Dither);
            exit when Pixel_Outcome /= Pixel_Ready;
            Position := Position + Bytes_Per_Pixel;
         end loop;
      end Map_Formatted_Row;

      procedure Map_Indexed is new Map_Formatted_Row
        (Pixels.Read_Indexed_8_Validated, 1, False);
      procedure Map_RGB is new Map_Formatted_Row
        (Pixels.Read_RGB_24_Validated, 3, False);
      procedure Map_BGR is new Map_Formatted_Row
        (Pixels.Read_BGR_24_Validated, 3, False);
      procedure Map_RGBA is new Map_Formatted_Row
        (Pixels.Read_RGBA_32_Validated, 4, True);
      procedure Map_BGRA is new Map_Formatted_Row
        (Pixels.Read_BGRA_32_Validated, 4, True);
   begin
      Internal.Work_Budgets.Try_Charge
        (Work, Byte_Count (Source.Width), Accepted);
      if not Accepted then
         return Workspace_Service.Work_Failure (Work);
      end if;
      if Use_Dither then
         Internal.Work_Budgets.Try_Charge
           (Work, Byte_Count (3) * Byte_Count (Span), Accepted);
         if not Accepted then
            return Workspace_Service.Work_Failure (Work);
         end if;
         Status := Dither.Clear_Next_Row
           (Errors, Next_Group, Span);
         if Status /= Outcomes.Storage_Ready then
            return Workspace_Service.Invariant_Failure;
         end if;
      end if;
      case Source.Format is
         when Indexed_8 => Map_Indexed;
         when RGB_24 => Map_RGB;
         when BGR_24 => Map_BGR;
         when RGBA_32 => Map_RGBA;
         when BGRA_32 => Map_BGRA;
      end case;
      if Pixel_Outcome /= Pixel_Ready then
         return Workspace_Service.Invariant_Failure;
      end if;
      Internal.Work_Budgets.Try_Charge (Work, Nearest_Work, Accepted);
      if not Accepted then
         return Workspace_Service.Work_Failure (Work);
      end if;
      return Results.Success;
   end Map_Row;

   function Map
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Prepared : Palette_Building.Prepared_Palette;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Work : in out Internal.Work_Budgets.Meter) return Results.Result
   is
      Use_Dither : constant Boolean := Options.Dither = Floyd_Steinberg;
      Search : Mapping.Search_Index;
      Outcome : Results.Result;
      Mapping_Outcome : Results.Result := Results.Success;
      Update_Status : Outcomes.Storage_Status;
      Policy : Cache_Policy;

      procedure Map_With_Cache
        (Cache_State : in out Cache.Cache_State;
         Current_Epoch : Cache.Epoch)
      is
         Dummy_Errors : Dither.Error_State (0 .. 0) := [others => 0];

         procedure Map_With_Errors
           (Errors : in out Dither.Error_State)
         is
         begin
            for Y in 0 .. Natural (Source.Height) - 1 loop
               Mapping_Outcome := Map_Row
                 (Cache_State, Current_Epoch, Errors, Source, Y,
                  Indexed_Pixels, Prepared, Search, Options, Policy, Work,
                  Use_Dither);
               if not Results.Succeeded (Mapping_Outcome) then return; end if;
            end loop;
         end Map_With_Errors;
      begin
         if Use_Dither then
            Update_Status := Dither.Update
              (Context.Resources, Map_With_Errors'Access);
            if Update_Status /= Outcomes.Storage_Ready then
               Mapping_Outcome := Workspace_Service.Invariant_Failure;
            end if;
         else
            Map_With_Errors (Dummy_Errors);
         end if;
      end Map_With_Cache;
   begin
      Outcome := Prepare_Workspace
        (Context, Source.Width, Constraints, Work, Use_Dither);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Mapping.Build
        (Prepared.Value, Prepared.Generated_Start,
         Prepared.Has_Transparency
           and then Options.Palette.Strategy = Use_Fixed_Palette,
         Prepared.Transparent_Index, Work, Search);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Update_Status := Cache.Update
        (Context.Resources, Map_With_Cache'Access);
      if Update_Status /= Outcomes.Storage_Ready then
         return Workspace_Service.Invariant_Failure;
      end if;
      return Mapping_Outcome;
   end Map;
end Giflib.Quantization.Pixel_Mapping;
