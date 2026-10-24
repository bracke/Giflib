with Ada.Unchecked_Deallocation;

with Giflib.Errors;
with Giflib.Internal.Budget_Arithmetic;
with Giflib.Internal.Geometry_Arithmetic;
with Giflib.Internal.Quantization_Arithmetic;
with Giflib.Internal.Quantization_Buffer_Arithmetic;
with Giflib.Internal.Quantization_Pixels;

package body Giflib.Quantization is
   use type Internal.Ownership.Allocation_Status;
   use type Palettes.RGB_Color;

   package Arithmetic renames Internal.Quantization_Arithmetic;
   package Buffer_Arithmetic renames Internal.Quantization_Buffer_Arithmetic;
   package Dithering renames Internal.Quantization_Dithering;
   package Palette_Builder renames Internal.Quantization_Palette;
   package Pixels renames Internal.Quantization_Pixels;
   subtype Histogram_Index is Palette_Builder.Histogram_Index;

   type Work_Tracker is record
      Total : Byte_Count := 0;
      Failed : Boolean := False;
      Attempted : Byte_Count := 0;
   end record;

   function Charge
     (Tracker : in out Work_Tracker;
      Maximum : Byte_Count;
      Amount : Byte_Count := 1) return Boolean
   is
      Budget : constant Internal.Budget_Arithmetic.Charge_Result :=
        Internal.Budget_Arithmetic.Charge
          (Tracker.Total, Maximum, Amount);
   begin
      if not Budget.Accepted then
         Tracker.Failed := True;
         Tracker.Attempted := Budget.Attempted;
         return False;
      end if;
      Tracker.Total := Budget.Total;
      return True;
   end Charge;

   procedure Free_Histogram_State is new Ada.Unchecked_Deallocation
     (Histogram_State, Histogram_State_Access);

   Nearest_Cache_Probe_Limit : constant := 8;
   procedure Free_Nearest_Cache is new Ada.Unchecked_Deallocation
     (Nearest_Cache_Array, Nearest_Cache_Access);

   procedure Free_Errors is new Ada.Unchecked_Deallocation
     (Error_Array, Error_Array_Access);

   function Histogram_Charge return Byte_Count is
     (Internal.Ownership.Storage_Bytes (Histogram_State'Object_Size));
   function Nearest_Cache_Charge return Byte_Count is
     (Internal.Ownership.Storage_Bytes (Nearest_Cache_Array'Object_Size));

   function Error_Charge (Length : Natural) return Byte_Count is
     (Byte_Count (Length)
      * Internal.Ownership.Storage_Bytes (Long_Integer'Object_Size));

   procedure Release
     (Budget : in out Internal.Ownership.Byte_Budget;
      Amount : Byte_Count)
   is
   begin
      Internal.Ownership.Release (Budget, Amount);
   end Release;

   function Allocated_Bytes (Context : Workspace) return Byte_Count is
   begin
      return Internal.Ownership.Used (Context.Resources.Allocation_Budget);
   end Allocated_Bytes;

   function Cleanup_Succeeded (Context : Workspace) return Boolean is
     (not Context.Resources.Cleanup_Failed);

   procedure Release_All
     (Resources : in out Workspace_Resources;
      Budget : in out Internal.Ownership.Byte_Budget)
   is
      Failed : Boolean := False;

      procedure Release_Histogram is
      begin
         if Resources.Histogram /= null then
            begin
               Release (Budget, Histogram_Charge);
            exception
               when others =>
                  Failed := True;
            end;
            begin
               Free_Histogram_State (Resources.Histogram);
            exception
               when others =>
                  Failed := True;
            end;
         end if;
      end Release_Histogram;

      procedure Release_Nearest_Cache is
      begin
         if Resources.Nearest_Cache /= null then
            begin
               Release (Budget, Nearest_Cache_Charge);
            exception
               when others =>
                  Failed := True;
            end;
            begin
               Free_Nearest_Cache (Resources.Nearest_Cache);
            exception
               when others =>
                  Failed := True;
            end;
         end if;
      end Release_Nearest_Cache;

      procedure Release_Error_Buffer is
         Amount : Byte_Count := 0;
      begin
         if Resources.Errors /= null then
            begin
               Amount := Error_Charge (Resources.Errors'Length);
               Release (Budget, Amount);
            exception
               when others =>
                  Failed := True;
            end;
            begin
               Free_Errors (Resources.Errors);
            exception
               when others =>
                  Failed := True;
            end;
         end if;
      end Release_Error_Buffer;
   begin
      Release_Histogram;
      Release_Nearest_Cache;
      Release_Error_Buffer;
      Resources.Cleanup_Failed := Resources.Cleanup_Failed or else Failed;
   end Release_All;

   overriding procedure Finalize (Resources : in out Workspace_Resources) is
   begin
      Release_All (Resources, Resources.Allocation_Budget);
   end Finalize;

   procedure Finalize (Context : in out Workspace) is
   begin
      Release_All
        (Context.Resources, Context.Resources.Allocation_Budget);
   end Finalize;

   function Allocation_Failure
     (Constraints : Limits.Limit_Set;
      Attempted : Byte_Count) return Results.Result
   is
   begin
      return Results.Failure
        (Giflib.Errors.Make
           (Giflib.Errors.Limit_Exceeded,
            (Expected => Constraints.Max_Allocation_Bytes,
             Actual => Attempted,
             Limit => Allocation_Byte_Limit,
             others => <>)));
   end Allocation_Failure;

   function Ensure_Nearest_Cache
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Allocation : constant Byte_Count := Nearest_Cache_Charge;
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Context.Resources.Allocation_Budget;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Context.Resources.Nearest_Cache /= null then
         return Results.Success;
      end if;
      declare
         Ticket : Internal.Ownership.Reservation (Budget'Access);
      begin
         Outcome := Internal.Ownership.Reserve
           (Ticket, Fault, Constraints.Max_Allocation_Bytes, Allocation);
         if Outcome.Status = Internal.Ownership.Allocation_Ready then
            begin
               Context.Resources.Nearest_Cache := new Nearest_Cache_Array;
               Internal.Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Internal.Ownership.Cancel (Ticket, Outcome);
            end;
         end if;
      end;
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Failure (Constraints, Outcome.Attempted);
      end if;
      return Results.Success;
   end Ensure_Nearest_Cache;

   function Ensure_Histogram
     (Context : in out Workspace;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Allocation : constant Byte_Count := Histogram_Charge;
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Context.Resources.Allocation_Budget;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Context.Resources.Histogram /= null then
         return Results.Success;
      end if;
      declare
         Ticket : Internal.Ownership.Reservation (Budget'Access);
      begin
         Outcome := Internal.Ownership.Reserve
           (Ticket, Fault, Constraints.Max_Allocation_Bytes, Allocation);
         if Outcome.Status = Internal.Ownership.Allocation_Ready then
            begin
               Context.Resources.Histogram := new Histogram_State;
               Internal.Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Internal.Ownership.Cancel (Ticket, Outcome);
            end;
         end if;
      end;
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Failure (Constraints, Outcome.Attempted);
      end if;
      return Results.Success;
   end Ensure_Histogram;

   function Ensure_Error_Buffer
     (Context : in out Workspace;
      Width : Image_Width;
      Constraints : Limits.Limit_Set) return Results.Result
   is
      Allocation : constant Byte_Count :=
        Buffer_Arithmetic.Allocation_Bytes
          (Width,
           Positive
             (Internal.Ownership.Storage_Bytes
                (Long_Integer'Object_Size)));
      Outcome : Internal.Ownership.Allocation_Outcome;
      Budget : Internal.Ownership.Byte_Budget renames
        Context.Resources.Allocation_Budget;
      Fault : Internal.Ownership.Fault_State renames Context.Allocation_Fault;

   begin
      if Context.Resources.Errors /= null
        and then Error_Charge (Context.Resources.Errors'Length) >= Allocation
      then
         return Results.Success;
      end if;
      if Context.Resources.Errors /= null then
         Release (Budget, Error_Charge (Context.Resources.Errors'Length));
         Free_Errors (Context.Resources.Errors);
      end if;
      declare
         Ticket : Internal.Ownership.Reservation (Budget'Access);
      begin
         Outcome := Internal.Ownership.Reserve
           (Ticket, Fault, Constraints.Max_Allocation_Bytes, Allocation);
         if Outcome.Status = Internal.Ownership.Allocation_Ready then
            begin
               Context.Resources.Errors := new Error_Array
                 (0 .. Buffer_Arithmetic.Error_Buffer_Length (Width) - 1);
               Internal.Ownership.Commit (Ticket);
            exception
               when Storage_Error =>
                  Internal.Ownership.Cancel (Ticket, Outcome);
            end;
         end if;
      end;
      if Outcome.Status /= Internal.Ownership.Allocation_Ready then
         return Allocation_Failure (Constraints, Outcome.Attempted);
      end if;
      return Results.Success;
   end Ensure_Error_Buffer;

   function Validate_Request
     (Context : Workspace;
      Source : Images.Image_View;
      Indexed_Length : Natural;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Pixel_Total : Byte_Count) return Results.Result
   is
      Outcome : constant Results.Result := Images.Validate (Source);
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Source.Format = Indexed_8 then
         return Results.Failure
           (Giflib.Errors.Make (Giflib.Errors.Unsupported_Feature));
      elsif Byte_Count (Indexed_Length) /= Pixel_Total then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Invalid_Dimensions,
               (Expected => Pixel_Total,
                Actual => Byte_Count (Indexed_Length),
                others => <>)));
      elsif Pixel_Total > Byte_Count (Constraints.Max_Frame_Pixels) then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Byte_Count (Constraints.Max_Frame_Pixels),
                Actual => Pixel_Total,
                Limit => Frame_Pixel_Limit,
                others => <>)));
      elsif Options.Strategy = Use_Fixed_Palette
        and then Options.Fixed_Palette.Length < 2
      then
         return Results.Failure
           (Giflib.Errors.Make (Giflib.Errors.Missing_Color_Table));
      elsif Allocated_Bytes (Context) > Constraints.Max_Allocation_Bytes then
         return Results.Failure
           (Giflib.Errors.Make
              (Giflib.Errors.Limit_Exceeded,
               (Expected => Constraints.Max_Allocation_Bytes,
                Actual => Allocated_Bytes (Context),
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;
      return Results.Success;
   end Validate_Request;

   function Map_Pixels
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : Palettes.Palette;
      Has_Transparency : Boolean;
      Transparent_Index : Palette_Index;
      Generated_Start : Natural;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set;
      Tracker : in out Work_Tracker) return Results.Result
   is separate;

   function Quantize_With_Resources
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options;
      Constraints : Limits.Limit_Set) return Results.Result
   is separate;

   function Quantize
     (Context : in out Workspace;
      Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      return Quantize_With_Resources
        (Context, Source, Indexed_Pixels, Output_Palette, Has_Transparency,
         Transparent_Index, Options, Constraints);
   end Quantize;

   function Quantize
     (Source : Images.Image_View;
      Indexed_Pixels : out Streams.Byte_Array;
      Output_Palette : out Palettes.Palette;
      Has_Transparency : out Boolean;
      Transparent_Index : out Palette_Index;
      Options : Quantize_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      Context : Workspace;
   begin
      return Quantize
        (Context, Source, Indexed_Pixels, Output_Palette, Has_Transparency,
         Transparent_Index, Options, Constraints);
   end Quantize;
end Giflib.Quantization;
