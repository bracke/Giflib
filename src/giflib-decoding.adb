with Ada.Unchecked_Deallocation;
with Giflib.Internal.Blocks;
with Giflib.Internal.Bytes;
with Giflib.Internal.Container;
with Giflib.Internal.Image_Data;
with Giflib.Palettes;

package body Giflib.Decoding is
   use type Errors.Error_Code;
   use type Errors.Warning_Code;
   use type Frames.Disposal_Method;
   use type Metadata.Extension_Kind;
   use type Streams.Byte_Array_Access;

   procedure Free_Chunk is new Ada.Unchecked_Deallocation (Payload_Chunk, Payload_Chunk_Access);
   procedure Free_Node is new Ada.Unchecked_Deallocation (Extension_Node, Extension_Node_Access);
   procedure Free_Bytes is new Ada.Unchecked_Deallocation (Streams.Byte_Array, Streams.Byte_Array_Access);

   procedure Release_Images (Object : in out Decoder) is
   begin
      if Object.Canvas /= null then
         Free_Bytes (Object.Canvas);
      end if;
      if Object.Snapshot /= null then
         Free_Bytes (Object.Snapshot);
      end if;
      Object.Canvas := null;
      Object.Snapshot := null;
      Object.Owned_Allocation_Bytes := 0;
      Object.Has_Previous_Frame := False;
      Object.Previous_Control := Frames.Default_Control;
   end Release_Images;

   procedure Release_Metadata (Object : in out Decoder) is
      Node : Extension_Node_Access := Object.Retained_First;
      Next_Node : Extension_Node_Access;
      Chunk : Payload_Chunk_Access;
      Next_Chunk : Payload_Chunk_Access;
   begin
      while Node /= null loop
         Chunk := Node.First_Chunk;
         while Chunk /= null loop
            Next_Chunk := Chunk.Next;
            Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes - 512;
            Free_Chunk (Chunk);
            Chunk := Next_Chunk;
         end loop;
         Next_Node := Node.Next;
         Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes - 512;
         Free_Node (Node);
         Node := Next_Node;
      end loop;
      Object.Retained_First := null;
      Object.Retained_Last := null;
      Object.Retained_Count := 0;
      Object.Retained_Bytes := 0;
   end Release_Metadata;

   function Invalid_Transition (Object : Decoder) return Results.Result is
      Offset : Source_Offset := 0;
   begin
      if Object.Input /= null then
         Offset := Object.Input.Offset;
      end if;
      return Results.Failure
        (Errors.Make
           (Errors.Invalid_State,
            (Source => Offset, others => <>)));
   end Invalid_Transition;

   function Fail (Object : in out Decoder; Item : Errors.Error) return Results.Result is
   begin
      if Object.Diagnostic.Code = Errors.No_Error then
         Object.Diagnostic := Item;
      end if;
      Release_Metadata (Object);
      Release_Images (Object);
      Object.Current_State := Failed;
      return Results.Failure (Object.Diagnostic);
   end Fail;

   procedure Add_Warning
     (Object : in out Decoder;
      Code : Errors.Warning_Code;
      Severity : Errors.Warning_Severity;
      Context : Errors.Diagnostic_Context := (others => <>))
   is
      Capacity : constant Natural := Natural'Min
        (Natural'Min (Object.Constraints.Max_Warning_Records,
                      Object.Constraints.Max_Diagnostic_Events),
         256);
   begin
      if Capacity = 0 then
         return;
      elsif Object.Stored_Warnings < Capacity then
         Object.Stored_Warnings := Object.Stored_Warnings + 1;
         Object.Warnings (Object.Stored_Warnings) := Errors.Make_Warning (Code, Severity, Context);
      elsif Object.Warnings (Capacity).Code /= Errors.Warnings_Suppressed then
         Object.Warnings (Capacity) :=
           Errors.Make_Warning (Errors.Warnings_Suppressed, Errors.Data_Loss, Context);
      end if;
   end Add_Warning;

   function Check_Trailing_Data (Object : in out Decoder) return Results.Result is
      Buffer : Streams.Byte_Array (1 .. 1);
      Step : Streams.Source_Result;
      Offset : constant Source_Offset := Object.Input.Offset;
   begin
      Step := Object.Input.Read (Buffer);
      if Errors.Is_Fatal (Step.Error) then
         return Results.Failure (Step.Error);
      elsif Step.Count = 0 and then Step.End_Of_Input then
         return Results.Success;
      elsif Step.Count = 0 then
         return Results.Failure
           (Errors.Make (Errors.Source_Zero_Progress, (Source => Offset, others => <>)));
      elsif Object.Options.Strictness = Strict then
         return Results.Failure
           (Errors.Make
              (Errors.Trailing_Data,
               (Source => Offset,
                Block => Trailing_Data_Block,
                Expected => 0,
                Actual => Step.Count,
                others => <>)));
      end if;
      Add_Warning
        (Object,
         Errors.Trailing_Data_Ignored,
         Errors.Compatibility,
         (Source => Offset, Block => Trailing_Data_Block, Actual => Step.Count, others => <>));
      return Results.Success;
   end Check_Trailing_Data;

   function To_Internal_Header (Item : Header_Info) return Internal.Container.Header_Info is
   begin
      return
        (Version => Item.Version,
         Width => Item.Width,
         Height => Item.Height,
         Has_Global_Palette => Item.Has_Global_Palette,
         Global_Palette => Item.Global_Palette,
         Color_Resolution => Item.Color_Resolution,
         Global_Palette_Sorted => Item.Global_Palette_Sorted,
         Background_Index => Item.Background_Index,
         Pixel_Aspect_Ratio => Item.Pixel_Aspect_Ratio);
   end To_Internal_Header;

   function Setup_Canvas (Object : in out Decoder) return Results.Result is
      Pixels : constant Byte_Count :=
        Byte_Count (Object.Header_Data.Width) * Byte_Count (Object.Header_Data.Height);
      Bytes : constant Byte_Count := Pixels * 4;
      Background : Palettes.RGB_Color := (others => 0);
      Has_Background : Boolean := False;
   begin
      if Pixels > Byte_Count (Object.Constraints.Max_Canvas_Pixels) then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Expected => Byte_Count (Object.Constraints.Max_Canvas_Pixels),
                Actual => Pixels,
                Limit => Canvas_Pixel_Limit,
                others => <>)));
      elsif Bytes > Object.Constraints.Max_Canvas_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Expected => Object.Constraints.Max_Canvas_Bytes,
                Actual => Bytes,
                Limit => Canvas_Byte_Limit,
                others => <>)));
      elsif Bytes > Byte_Count (Natural'Last) then
         return Results.Failure
           (Errors.Make (Errors.Integer_Overflow, (Source => Object.Input.Offset, others => <>)));
      elsif Object.Owned_Allocation_Bytes > Object.Constraints.Max_Allocation_Bytes
        or else Bytes > Object.Constraints.Max_Allocation_Bytes - Object.Owned_Allocation_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Expected => Object.Constraints.Max_Allocation_Bytes,
                Actual => Object.Owned_Allocation_Bytes + Bytes,
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;
      begin
         Object.Canvas := new Streams.Byte_Array (1 .. Natural (Bytes));
      exception
         when Storage_Error =>
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Object.Input.Offset,
                   Expected => Object.Constraints.Max_Allocation_Bytes,
                   Actual => Object.Owned_Allocation_Bytes + Bytes,
                   Limit => Allocation_Byte_Limit,
                   others => <>)));
      end;
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes + Bytes;
      if Object.Header_Data.Has_Global_Palette
        and then Palettes.Contains
          (Object.Header_Data.Global_Palette, Object.Header_Data.Background_Index)
      then
         Background := Object.Header_Data.Global_Palette.Colors (Object.Header_Data.Background_Index);
         Has_Background := True;
      end if;
      for Pixel in 0 .. Natural (Pixels) - 1 loop
         Object.Canvas (Object.Canvas'First + Pixel * 4) := Background.Red;
         Object.Canvas (Object.Canvas'First + Pixel * 4 + 1) := Background.Green;
         Object.Canvas (Object.Canvas'First + Pixel * 4 + 2) := Background.Blue;
         Object.Canvas (Object.Canvas'First + Pixel * 4 + 3) := (if Has_Background then 255 else 0);
      end loop;
      return Results.Success;
   end Setup_Canvas;

   function Should_Retain
     (Policy : Metadata.Retention_Policy;
      Kind : Metadata.Extension_Kind) return Boolean
   is
   begin
      case Policy is
         when Metadata.Discard_All | Metadata.Parse_Known_Without_Retention =>
            return False;
         when Metadata.Retain_Selected =>
            return Kind in Metadata.Comment_Extension | Metadata.Application_Extension;
         when Metadata.Retain_All_Bounded | Metadata.Retain_All_Exact_Bounded =>
            return True;
      end case;
   end Should_Retain;

   function Start_Retention
     (Object : in out Decoder;
      Info : Metadata.Extension_Info;
      Node : out Extension_Node_Access) return Results.Result
   is
      Charge : constant Byte_Count := 512;
   begin
      Node := null;
      if not Should_Retain (Object.Options.Retention, Info.Kind) then
         return Results.Success;
      elsif Object.Owned_Allocation_Bytes > Object.Constraints.Max_Allocation_Bytes
        or else Charge > Object.Constraints.Max_Allocation_Bytes - Object.Owned_Allocation_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Info.Offset,
                Expected => Object.Constraints.Max_Allocation_Bytes,
                Actual => Object.Owned_Allocation_Bytes + Charge,
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;

      begin
         Node := new Extension_Node'(Info => Info, others => <>);
      exception
         when Storage_Error =>
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Info.Offset,
                   Expected => Object.Constraints.Max_Allocation_Bytes,
                   Actual => Object.Owned_Allocation_Bytes + Charge,
                   Limit => Allocation_Byte_Limit,
                   others => <>)));
      end;
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes + Charge;
      if Object.Retained_Last = null then
         Object.Retained_First := Node;
      else
         Object.Retained_Last.Next := Node;
      end if;
      Object.Retained_Last := Node;
      Object.Retained_Count := Object.Retained_Count + 1;
      return Results.Success;
   end Start_Retention;

   function Retain_Chunk
     (Object : in out Decoder;
      Node : Extension_Node_Access;
      Data : Streams.Byte_Array) return Results.Result
   is
      Charge : constant Byte_Count := 512;
      Chunk : Payload_Chunk_Access;
   begin
      if Node = null or else Data'Length = 0 then
         return Results.Success;
      elsif Data'Length > 255 then
         return Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed));
      elsif Object.Retained_Bytes > Object.Constraints.Max_Retained_Metadata_Bytes
        or else Byte_Count (Data'Length) >
          Object.Constraints.Max_Retained_Metadata_Bytes - Object.Retained_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Node.Info.Offset,
                Expected => Object.Constraints.Max_Retained_Metadata_Bytes,
                Actual => Object.Retained_Bytes + Byte_Count (Data'Length),
                Limit => Retained_Metadata_Byte_Limit,
                others => <>)));
      elsif Object.Owned_Allocation_Bytes > Object.Constraints.Max_Allocation_Bytes
        or else Charge > Object.Constraints.Max_Allocation_Bytes - Object.Owned_Allocation_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Node.Info.Offset,
                Expected => Object.Constraints.Max_Allocation_Bytes,
                Actual => Object.Owned_Allocation_Bytes + Charge,
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;

      begin
         Chunk := new Payload_Chunk;
      exception
         when Storage_Error =>
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Node.Info.Offset,
                   Expected => Object.Constraints.Max_Allocation_Bytes,
                   Actual => Object.Owned_Allocation_Bytes + Charge,
                   Limit => Allocation_Byte_Limit,
                   others => <>)));
      end;
      Chunk.Length := Data'Length;
      for I in 0 .. Data'Length - 1 loop
         Chunk.Data (Chunk.Data'First + I) := Data (Data'First + I);
      end loop;
      if Node.Last_Chunk = null then
         Node.First_Chunk := Chunk;
      else
         Node.Last_Chunk.Next := Chunk;
      end if;
      Node.Last_Chunk := Chunk;
      Object.Retained_Bytes := Object.Retained_Bytes + Byte_Count (Data'Length);
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes + Charge;
      return Results.Success;
   end Retain_Chunk;

   function Extension_Truncated
     (Object : Decoder;
      Info : Metadata.Extension_Info;
      Outcome : Results.Result) return Results.Result
   is
   begin
      if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
         return Results.Failure
           (Errors.Make
              (Errors.Truncated_Block,
               (Source => Object.Input.Offset,
                Block => Unknown_Extension_Block,
                Extension_Label => Info.Label,
                others => <>)));
      end if;
      return Outcome;
   end Extension_Truncated;

   function Read_Sub_Blocks
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info;
      Node : Extension_Node_Access;
      First_Data : out Streams.Byte_Array;
      First_Length : out Natural) return Results.Result
   is
      Length_Byte : Byte;
      Buffer : Streams.Byte_Array (1 .. 255);
      Outcome : Results.Result;
      Length : Natural;
   begin
      First_Data := [others => 0];
      First_Length := 0;
      loop
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Length_Byte, Unknown_Extension_Block);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         end if;
         Length := Natural (Length_Byte);
         exit when Length = 0;
         if Info.Payload_Length > Object.Constraints.Max_Per_Extension_Bytes
           or else Byte_Count (Length) >
             Object.Constraints.Max_Per_Extension_Bytes - Info.Payload_Length
         then
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Object.Input.Offset,
                   Block => Unknown_Extension_Block,
                   Extension_Label => Info.Label,
                   Expected => Object.Constraints.Max_Per_Extension_Bytes,
                   Actual => Info.Payload_Length + Byte_Count (Length),
                   Limit => Per_Extension_Byte_Limit,
                   others => <>)));
         end if;
         Outcome := Streams.Read_Exact (Object.Input.all, Buffer (1 .. Length));
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         end if;
         if First_Length = 0 then
            First_Length := Length;
            First_Data (1 .. Length) := Buffer (1 .. Length);
         end if;
         Outcome := Retain_Chunk (Object, Node, Buffer (1 .. Length));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Info.Payload_Length := Info.Payload_Length + Byte_Count (Length);
         Info.Sub_Block_Count := Info.Sub_Block_Count + 1;
      end loop;
      return Results.Success;
   end Read_Sub_Blocks;

   function Read_Extension
     (Object : in out Decoder;
      Offset : Source_Offset;
      Label_Value : Byte;
      Info : out Metadata.Extension_Info) return Results.Result
   is
      use type Metadata.Application_Authentication_Code;
      use type Metadata.Application_Identifier;
      Node : Extension_Node_Access;
      Outcome : Results.Result;
      Size_Byte : Byte;
      Terminator : Byte;
      Fixed : Streams.Byte_Array (1 .. 12) := [others => 0];
      First_Data : Streams.Byte_Array (1 .. 255);
      First_Length : Natural;
      Packed : Natural;
      Control : Frames.Graphic_Control;
      Netscape : constant Metadata.Application_Identifier :=
        [Character'Pos ('N'), Character'Pos ('E'), Character'Pos ('T'), Character'Pos ('S'),
         Character'Pos ('C'), Character'Pos ('A'), Character'Pos ('P'), Character'Pos ('E')];
      Animexts : constant Metadata.Application_Identifier :=
        [Character'Pos ('A'), Character'Pos ('N'), Character'Pos ('I'), Character'Pos ('M'),
         Character'Pos ('E'), Character'Pos ('X'), Character'Pos ('T'), Character'Pos ('S')];
      Netscape_Auth : constant Metadata.Application_Authentication_Code :=
        [Character'Pos ('2'), Character'Pos ('.'), Character'Pos ('0')];
      Animexts_Auth : constant Metadata.Application_Authentication_Code :=
        [Character'Pos ('1'), Character'Pos ('.'), Character'Pos ('0')];
   begin
      Info :=
        (Label => Label_Value,
         Offset => Offset,
         Before_Frame => Object.Frames_Seen,
         others => <>);
      case Label_Value is
         when 16#F9# => Info.Kind := Metadata.Graphic_Control_Extension;
         when 16#FE# => Info.Kind := Metadata.Comment_Extension;
         when 16#01# => Info.Kind := Metadata.Plain_Text_Extension;
         when 16#FF# => Info.Kind := Metadata.Application_Extension;
         when others => Info.Kind := Metadata.Unknown_Extension;
      end case;

      if Object.Extensions_Seen >= Object.Constraints.Max_Extensions then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Offset,
                Extension_Label => Label_Value,
                Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Seen) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      Object.Extensions_Seen := Object.Extensions_Seen + 1;

      if Info.Kind = Metadata.Graphic_Control_Extension then
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Size_Byte, Graphic_Control_Extension_Block);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         elsif Size_Byte /= 4 then
            return Results.Failure
              (Errors.Make
                 (Errors.Invalid_Extension,
                  (Source => Object.Input.Offset - 1,
                   Block => Graphic_Control_Extension_Block,
                   Extension_Label => Label_Value,
                   Expected => 4,
                   Actual => Byte_Count (Size_Byte),
                   others => <>)));
         end if;
         Outcome := Streams.Read_Exact (Object.Input.all, Fixed (1 .. 4));
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         end if;
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Terminator, Graphic_Control_Extension_Block);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         elsif Terminator /= 0 then
            return Results.Failure
              (Errors.Make
                 (Errors.Invalid_Extension,
                  (Source => Object.Input.Offset - 1,
                   Block => Graphic_Control_Extension_Block,
                   Extension_Label => Label_Value,
                   Expected => 0,
                   Actual => Byte_Count (Terminator),
                   others => <>)));
         elsif Object.Has_Pending_Control and then Object.Options.Strictness = Strict then
            return Results.Failure
              (Errors.Make
                 (Errors.Duplicate_Graphic_Control,
                  (Source => Offset, Block => Graphic_Control_Extension_Block, others => <>)));
         end if;
         Packed := Natural (Fixed (1));
         if Packed / 32 /= 0 then
            if Object.Options.Strictness = Strict then
               return Results.Failure
                 (Errors.Make
                    (Errors.Invalid_Extension,
                     (Source => Offset,
                      Block => Graphic_Control_Extension_Block,
                      Extension_Label => Label_Value,
                      Actual => Byte_Count (Packed),
                      others => <>)));
            end if;
            Add_Warning
              (Object,
               Errors.Reserved_Value_Accepted,
               Errors.Compatibility,
               (Source => Offset,
                Block => Graphic_Control_Extension_Block,
                Extension_Label => Label_Value,
                Actual => Byte_Count (Packed),
                others => <>));
         end if;
         if Object.Has_Pending_Control then
            Add_Warning
              (Object,
               Errors.Compatibility_Issue,
               Errors.Compatibility,
               (Source => Offset, Block => Graphic_Control_Extension_Block, others => <>));
         end if;
         Control :=
           (Disposal => Frames.Disposal_Method ((Packed / 4) mod 8),
            User_Input => (Packed / 2) mod 2 = 1,
            Delay_CS => Delay_Centiseconds (Natural (Fixed (2)) + 256 * Natural (Fixed (3))),
            Has_Transparency => Packed mod 2 = 1,
            Transparent_Index => Palette_Index (Fixed (4)));
         Object.Pending_Control := Control;
         Object.Has_Pending_Control := True;
         Info.Payload_Length := 4;
         Info.Sub_Block_Count := 1;
         Outcome := Start_Retention (Object, Info, Node);
         if Results.Succeeded (Outcome) then
            Outcome := Retain_Chunk (Object, Node, Fixed (1 .. 4));
         end if;
      elsif Info.Kind = Metadata.Application_Extension then
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Size_Byte, Application_Extension_Block);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         elsif Size_Byte /= 11 then
            return Results.Failure
              (Errors.Make
                 (Errors.Invalid_Extension,
                  (Source => Object.Input.Offset - 1,
                   Block => Application_Extension_Block,
                   Extension_Label => Label_Value,
                   Expected => 11,
                   Actual => Byte_Count (Size_Byte),
                   others => <>)));
         end if;
         Outcome := Streams.Read_Exact (Object.Input.all, Fixed (1 .. 11));
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         end if;
         Info.Has_Application_Identifier := True;
         for I in Info.Identifier'Range loop
            Info.Identifier (I) := Fixed (I);
         end loop;
         for I in Info.Authentication_Code'Range loop
            Info.Authentication_Code (I) := Fixed (8 + I);
         end loop;
         Info.Payload_Length := 11;
         Info.Sub_Block_Count := 1;
         Outcome := Start_Retention (Object, Info, Node);
         if Results.Succeeded (Outcome) then
            Outcome := Retain_Chunk (Object, Node, Fixed (1 .. 11));
         end if;
         if Results.Succeeded (Outcome) then
            Outcome := Read_Sub_Blocks (Object, Info, Node, First_Data, First_Length);
         end if;
         if Results.Succeeded (Outcome)
           and then First_Length = 3
           and then First_Data (1) = 1
           and then ((Info.Identifier = Netscape and then Info.Authentication_Code = Netscape_Auth)
                     or else (Info.Identifier = Animexts and then Info.Authentication_Code = Animexts_Auth))
         then
            Info.Is_Loop_Extension := True;
            Info.Loop_Count := Natural (First_Data (2)) + 256 * Natural (First_Data (3));
            Object.Loop_Data :=
              (State => (if Info.Loop_Count = 0
                         then Animations.Infinite_Looping
                         else Animations.Finite_Loop_Count),
               Raw_Count => Info.Loop_Count);
         end if;
      elsif Info.Kind = Metadata.Plain_Text_Extension then
         Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Size_Byte, Plain_Text_Extension_Block);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         elsif Size_Byte /= 12 then
            return Results.Failure
              (Errors.Make
                 (Errors.Invalid_Extension,
                  (Source => Object.Input.Offset - 1,
                   Block => Plain_Text_Extension_Block,
                   Extension_Label => Label_Value,
                   Expected => 12,
                   Actual => Byte_Count (Size_Byte),
                   others => <>)));
         end if;
         Outcome := Streams.Read_Exact (Object.Input.all, Fixed);
         if not Results.Succeeded (Outcome) then
            return Extension_Truncated (Object, Info, Outcome);
         end if;
         Info.Payload_Length := 12;
         Info.Sub_Block_Count := 1;
         Outcome := Start_Retention (Object, Info, Node);
         if Results.Succeeded (Outcome) then
            Outcome := Retain_Chunk (Object, Node, Fixed);
         end if;
         if Results.Succeeded (Outcome) then
            Outcome := Read_Sub_Blocks (Object, Info, Node, First_Data, First_Length);
         end if;
         if Results.Succeeded (Outcome) then
            Object.Pending_Control := Frames.Default_Control;
            Object.Has_Pending_Control := False;
         end if;
      else
         Outcome := Start_Retention (Object, Info, Node);
         if Results.Succeeded (Outcome) then
            Outcome := Read_Sub_Blocks (Object, Info, Node, First_Data, First_Length);
         end if;
      end if;

      if Results.Succeeded (Outcome) and then Node /= null then
         Node.Info := Info;
      end if;
      return Outcome;
   end Read_Extension;

   function Initialize
     (Object : in out Decoder;
      Input : not null Source_Access;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      if Object.Current_State not in Uninitialized | Finalized then
         return Invalid_Transition (Object);
      end if;
      Object.Input := Input;
      Object.Options := Options;
      Object.Constraints := Constraints;
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Release_Metadata (Object);
      Release_Images (Object);
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Stored_Warnings := 0;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      Object.Current_State := Initialized;
      return Results.Success;
   end Initialize;

   function Reset
     (Object : in out Decoder;
      Input : not null Source_Access;
      Options : Decode_Options := Default_Options;
      Constraints : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
   begin
      Object.Input := null;
      Object.Current_State := Uninitialized;
      Object.Diagnostic := Errors.Make (Errors.No_Error);
      return Initialize (Object, Input, Options, Constraints);
   end Reset;

   function Read_Header
     (Object : in out Decoder;
      Header : out Header_Info) return Results.Result
   is
      Parsed : Internal.Container.Header_Info;
      Outcome : Results.Result;
   begin
      Header := (others => <>);
      if Object.Current_State /= Initialized or else Object.Input = null then
         return Invalid_Transition (Object);
      end if;
      Outcome := Internal.Container.Read_Header (Object.Input.all, Object.Constraints, Parsed);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Header :=
        (Version => Parsed.Version,
         Width => Parsed.Width,
         Height => Parsed.Height,
         Has_Global_Palette => Parsed.Has_Global_Palette,
         Global_Palette => Parsed.Global_Palette,
         Color_Resolution => Parsed.Color_Resolution,
         Global_Palette_Sorted => Parsed.Global_Palette_Sorted,
         Background_Index => Parsed.Background_Index,
         Pixel_Aspect_Ratio => Parsed.Pixel_Aspect_Ratio);
      Object.Header_Data := Header;
      if Object.Options.Mode = Composited_RGBA then
         Outcome := Setup_Canvas (Object);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
      end if;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Read_Header;

   function Next_Event
     (Object : in out Decoder;
      Event : out Decode_Event) return Results.Result
   is
      Marker : Byte;
      Label_Value : Byte;
      Marker_Offset : Source_Offset;
      Extension_Info : Metadata.Extension_Info;
      Outcome : Results.Result;
   begin
      Event := (others => <>);
      if Object.Current_State = Completed then
         Event := (Kind => End_Event, Offset => Object.Input.Offset, others => <>);
         return Results.Success;
      elsif Object.Current_State /= Header_Ready or else Object.Input = null then
         return Invalid_Transition (Object);
      end if;

      Marker_Offset := Object.Input.Offset;
      Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Marker);
      if not Results.Succeeded (Outcome) then
         if Outcome.First_Error.Code = Errors.Source_Unexpected_End then
            if Object.Options.Strictness = Recover_When_Safe and then Object.Frames_Seen > 0 then
               Add_Warning
                 (Object,
                  Errors.Recovery_Applied,
                  Errors.Recovery,
                  (Source => Object.Input.Offset,
                   Block => Trailer_Block,
                   Expected => 1,
                   Actual => 0,
                   others => <>));
               Event := (Kind => End_Event, Offset => Object.Input.Offset, others => <>);
               Object.Current_State := Completed;
               return Results.Success;
            end if;
            return Fail
              (Object,
               Errors.Make
                 (Errors.Truncated_Block,
                  (Source => Object.Input.Offset, Expected => 1, Actual => 0, others => <>)));
         end if;
         return Fail (Object, Outcome.First_Error);
      end if;

      case Marker is
         when 16#2C# =>
            if Object.Frames_Seen >= Object.Constraints.Max_Frames then
               return Fail
                 (Object,
                  Errors.Make
                    (Errors.Limit_Exceeded,
                     (Source => Marker_Offset,
                      Block => Image_Descriptor_Block,
                      Expected => Byte_Count (Object.Constraints.Max_Frames),
                      Actual => Byte_Count (Object.Frames_Seen) + 1,
                      Limit => Frame_Count_Limit,
                      others => <>)));
            end if;
            Event :=
              (Kind => Image_Event,
               Offset => Marker_Offset,
               Frame => Object.Frames_Seen,
               Extension_Label => 0,
               Extension => <>);
            Object.Current_State := Awaiting_Frame_Decision;
            return Results.Success;
         when 16#3B# =>
            Outcome := Check_Trailing_Data (Object);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Event := (Kind => End_Event, Offset => Marker_Offset, others => <>);
            Object.Current_State := Completed;
            return Results.Success;
         when 16#21# =>
            Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Label_Value);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Outcome := Read_Extension (Object, Marker_Offset, Label_Value, Extension_Info);
            if not Results.Succeeded (Outcome) then
               return Fail (Object, Outcome.First_Error);
            end if;
            Event :=
              (Kind => Extension_Event,
               Offset => Marker_Offset,
               Frame => Object.Frames_Seen,
               Extension_Label => Label_Value,
               Extension => Extension_Info);
            return Results.Success;
         when others =>
            return Fail
              (Object,
               Errors.Make
                 (Errors.Invalid_Block,
                  (Source => Marker_Offset,
                   Expected => 16#2C#,
                   Actual => Byte_Count (Marker),
                   others => <>)));
      end case;
   end Next_Event;

   function Decode_Indexed_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is
      Descriptor : Internal.Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Outcome : Results.Result;
   begin
      Info := (others => <>);
      if Object.Current_State /= Awaiting_Frame_Decision or else Object.Input = null then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode /= Raw_Indexed then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               (Source => Object.Input.Offset, Frame => Object.Frames_Seen, others => <>)));
      end if;
      Object.Current_State := Decoding_Frame;
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         To_Internal_Header (Object.Header_Data),
         Object.Constraints,
         Descriptor,
         Palette,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      if Object.Has_Pending_Control
        and then Object.Pending_Control.Has_Transparency
        and then not Palettes.Contains (Palette, Object.Pending_Control.Transparent_Index)
      then
         return Fail
           (Object,
            Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               (Source => Object.Input.Offset,
                Block => Graphic_Control_Extension_Block,
                Frame => Object.Frames_Seen,
                Expected => Byte_Count (Palette.Length - 1),
                Actual => Byte_Count (Object.Pending_Control.Transparent_Index),
                others => <>)));
      end if;
      Outcome := Internal.Image_Data.Decode_Indices
        (Object.Input.all,
         Descriptor,
         Palette,
         Object.Constraints,
         Object.Total_Decoded_Pixels,
         Object.Total_Compressed_Bytes,
         Target,
         Object.Frames_Seen);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Info :=
        (Ordinal => Object.Frames_Seen,
         Left => Descriptor.Left,
         Top => Descriptor.Top,
         Width => Descriptor.Width,
         Height => Descriptor.Height,
         Interlaced => Descriptor.Interlaced,
         Has_Local_Palette => Descriptor.Has_Local_Palette,
         Local_Palette_Sorted => Descriptor.Local_Palette_Sorted,
         Effective_Palette => Palette,
         Control => (if Object.Has_Pending_Control
                     then Object.Pending_Control
                     else Frames.Default_Control));
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Decode_Indexed_Frame;

   function Decode_Expanded_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is
      Descriptor : Internal.Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control;
      Pixels : Byte_Count;
      Outcome : Results.Result;
      Source_Position, Target_Position : Natural;
      Index : Palette_Index;
      Color : Palettes.RGB_Color;
   begin
      Info := (others => <>);
      if Object.Current_State /= Awaiting_Frame_Decision or else Object.Input = null then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode /= Expanded_Frame then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               (Source => Object.Input.Offset, Frame => Object.Frames_Seen, others => <>)));
      end if;
      Object.Current_State := Decoding_Frame;
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         To_Internal_Header (Object.Header_Data),
         Object.Constraints,
         Descriptor,
         Palette,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Control := (if Object.Has_Pending_Control
                  then Object.Pending_Control
                  else Frames.Default_Control);
      if Control.Has_Transparency
        and then not Palettes.Contains (Palette, Control.Transparent_Index)
      then
         return Fail
           (Object,
            Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               (Source => Object.Input.Offset,
                Block => Graphic_Control_Extension_Block,
                Frame => Object.Frames_Seen,
                Expected => Byte_Count (Palette.Length - 1),
                Actual => Byte_Count (Control.Transparent_Index), others => <>)));
      end if;
      Pixels := Byte_Count (Descriptor.Width) * Byte_Count (Descriptor.Height);
      if Byte_Count (Target'Length) /= Pixels * 4 then
         return Fail
           (Object,
            Errors.Make
              (Errors.LZW_Output_Size_Mismatch,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Pixels * 4,
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      Outcome := Internal.Image_Data.Decode_Indices
        (Object.Input.all,
         Descriptor,
         Palette,
         Object.Constraints,
         Object.Total_Decoded_Pixels,
         Object.Total_Compressed_Bytes,
         Target (Target'First .. Target'First + Natural (Pixels) - 1),
         Object.Frames_Seen);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      for Pixel in reverse 0 .. Natural (Pixels) - 1 loop
         Source_Position := Target'First + Pixel;
         Target_Position := Target'First + Pixel * 4;
         Index := Palette_Index (Target (Source_Position));
         Color := Palette.Colors (Index);
         Target (Target_Position) := Color.Red;
         Target (Target_Position + 1) := Color.Green;
         Target (Target_Position + 2) := Color.Blue;
         Target (Target_Position + 3) :=
           (if Control.Has_Transparency and then Index = Control.Transparent_Index then 0 else 255);
      end loop;
      Info :=
        (Ordinal => Object.Frames_Seen,
         Left => Descriptor.Left,
         Top => Descriptor.Top,
         Width => Descriptor.Width,
         Height => Descriptor.Height,
         Interlaced => Descriptor.Interlaced,
         Has_Local_Palette => Descriptor.Has_Local_Palette,
         Local_Palette_Sorted => Descriptor.Local_Palette_Sorted,
         Effective_Palette => Palette,
         Control => Control);
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Decode_Expanded_Frame;

   procedure Fill_Background (Object : in out Decoder; Rectangle : Frames.Rectangle) is
      Color : Palettes.RGB_Color := (others => 0);
      Alpha : Byte := 0;
      Position : Natural;
   begin
      if Object.Header_Data.Has_Global_Palette
        and then Palettes.Contains
          (Object.Header_Data.Global_Palette, Object.Header_Data.Background_Index)
      then
         Color := Object.Header_Data.Global_Palette.Colors (Object.Header_Data.Background_Index);
         Alpha := 255;
      end if;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Position :=
              ((Natural (Rectangle.Top) + Row) * Natural (Object.Header_Data.Width)
               + Natural (Rectangle.Left) + Column) * 4;
            Object.Canvas (Object.Canvas'First + Position) := Color.Red;
            Object.Canvas (Object.Canvas'First + Position + 1) := Color.Green;
            Object.Canvas (Object.Canvas'First + Position + 2) := Color.Blue;
            Object.Canvas (Object.Canvas'First + Position + 3) := Alpha;
         end loop;
      end loop;
   end Fill_Background;

   procedure Release_Snapshot (Object : in out Decoder) is
   begin
      if Object.Snapshot /= null then
         Object.Owned_Allocation_Bytes :=
           Object.Owned_Allocation_Bytes - Byte_Count (Object.Snapshot'Length);
         Free_Bytes (Object.Snapshot);
         Object.Snapshot := null;
      end if;
   end Release_Snapshot;

   function Apply_Previous_Disposal (Object : in out Decoder) return Results.Result is
      Canvas_Position : Natural;
      Snapshot_Position : Natural := 0;
   begin
      if not Object.Has_Previous_Frame then
         return Results.Success;
      end if;
      case Object.Previous_Control.Disposal is
         when 2 =>
            Fill_Background (Object, Object.Previous_Rectangle);
         when 3 =>
            if Object.Snapshot = null then
               return Results.Failure
                 (Errors.Make
                    (Errors.Internal_Invariant_Failed,
                     (Source => Object.Input.Offset, Frame => Object.Frames_Seen, others => <>)));
            end if;
            for Row in 0 .. Natural (Object.Snapshot_Rectangle.Height) - 1 loop
               for Column in 0 .. Natural (Object.Snapshot_Rectangle.Width) - 1 loop
                  Canvas_Position :=
                    ((Natural (Object.Snapshot_Rectangle.Top) + Row)
                     * Natural (Object.Header_Data.Width)
                     + Natural (Object.Snapshot_Rectangle.Left) + Column) * 4;
                  for Component in 0 .. 3 loop
                     Object.Canvas (Object.Canvas'First + Canvas_Position + Component) :=
                       Object.Snapshot (Object.Snapshot'First + Snapshot_Position + Component);
                  end loop;
                  Snapshot_Position := Snapshot_Position + 4;
               end loop;
            end loop;
         when others =>
            null;
      end case;
      Release_Snapshot (Object);
      Object.Has_Previous_Frame := False;
      return Results.Success;
   end Apply_Previous_Disposal;

   function Save_Snapshot
     (Object : in out Decoder;
      Rectangle : Frames.Rectangle) return Results.Result
   is
      Bytes : constant Byte_Count :=
        Byte_Count (Rectangle.Width) * Byte_Count (Rectangle.Height) * 4;
      Canvas_Position : Natural;
      Snapshot_Position : Natural := 0;
   begin
      Release_Snapshot (Object);
      if Bytes > Object.Constraints.Max_Compositor_Snapshot_Bytes then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Object.Constraints.Max_Compositor_Snapshot_Bytes,
                Actual => Bytes,
                Limit => Snapshot_Byte_Limit,
                others => <>)));
      elsif Bytes > Byte_Count (Natural'Last) then
         return Results.Failure (Errors.Make (Errors.Integer_Overflow));
      elsif Object.Owned_Allocation_Bytes > Object.Constraints.Max_Allocation_Bytes
        or else Bytes > Object.Constraints.Max_Allocation_Bytes - Object.Owned_Allocation_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Object.Constraints.Max_Allocation_Bytes,
                Actual => Object.Owned_Allocation_Bytes + Bytes,
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;
      begin
         Object.Snapshot := new Streams.Byte_Array (1 .. Natural (Bytes));
      exception
         when Storage_Error =>
            return Results.Failure
              (Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Object.Input.Offset,
                   Frame => Object.Frames_Seen,
                   Expected => Object.Constraints.Max_Allocation_Bytes,
                   Actual => Object.Owned_Allocation_Bytes + Bytes,
                   Limit => Allocation_Byte_Limit,
                   others => <>)));
      end;
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes + Bytes;
      Object.Snapshot_Rectangle := Rectangle;
      for Row in 0 .. Natural (Rectangle.Height) - 1 loop
         for Column in 0 .. Natural (Rectangle.Width) - 1 loop
            Canvas_Position :=
              ((Natural (Rectangle.Top) + Row) * Natural (Object.Header_Data.Width)
               + Natural (Rectangle.Left) + Column) * 4;
            for Component in 0 .. 3 loop
               Object.Snapshot (Object.Snapshot'First + Snapshot_Position + Component) :=
                 Object.Canvas (Object.Canvas'First + Canvas_Position + Component);
            end loop;
            Snapshot_Position := Snapshot_Position + 4;
         end loop;
      end loop;
      return Results.Success;
   end Save_Snapshot;

   function Decode_Composited_Frame
     (Object : in out Decoder;
      Target : out Streams.Byte_Array;
      Info : out Frame_Info) return Results.Result
   is
      Descriptor : Internal.Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Control : Frames.Graphic_Control;
      Rectangle : Frames.Rectangle;
      Indices : Streams.Byte_Array_Access := null;
      Pixel_Bytes : Byte_Count;
      Outcome : Results.Result;
      Canvas_Position : Natural;
      Index_Position : Natural;
      Color : Palettes.RGB_Color;
   begin
      Info := (others => <>);
      if Object.Current_State /= Awaiting_Frame_Decision or else Object.Input = null then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode /= Composited_RGBA then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               (Source => Object.Input.Offset, Frame => Object.Frames_Seen, others => <>)));
      elsif Object.Canvas = null then
         return Fail (Object, Errors.Make (Errors.Internal_Invariant_Failed));
      elsif Target'Length /= Object.Canvas'Length then
         return Results.Failure
           (Errors.Make
              (Errors.LZW_Output_Size_Mismatch,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Byte_Count (Object.Canvas'Length),
                Actual => Byte_Count (Target'Length),
                others => <>)));
      end if;

      Outcome := Apply_Previous_Disposal (Object);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Object.Current_State := Decoding_Frame;
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         To_Internal_Header (Object.Header_Data),
         Object.Constraints,
         Descriptor,
         Palette,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Control := (if Object.Has_Pending_Control then Object.Pending_Control else Frames.Default_Control);
      if Control.Disposal > 3 and then Object.Options.Strictness = Strict then
         return Fail
           (Object,
            Errors.Make
              (Errors.Reserved_Disposal_Method,
               (Source => Object.Input.Offset,
                Block => Graphic_Control_Extension_Block,
                Frame => Object.Frames_Seen,
                Actual => Byte_Count (Control.Disposal),
                others => <>)));
      elsif Control.Disposal > 3 then
         Add_Warning
           (Object,
            Errors.Reserved_Value_Accepted,
            Errors.Compatibility,
            (Source => Object.Input.Offset,
             Block => Graphic_Control_Extension_Block,
             Frame => Object.Frames_Seen,
             Actual => Byte_Count (Control.Disposal),
             others => <>));
      end if;
      if Control.Has_Transparency and then not Palettes.Contains (Palette, Control.Transparent_Index) then
         return Fail
           (Object,
            Errors.Make
              (Errors.Palette_Index_Out_Of_Range,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Byte_Count (Palette.Length - 1),
                Actual => Byte_Count (Control.Transparent_Index),
                others => <>)));
      end if;
      Rectangle :=
        (Left => Descriptor.Left, Top => Descriptor.Top,
         Width => Descriptor.Width, Height => Descriptor.Height);
      if Control.Disposal = 3 then
         Outcome := Save_Snapshot (Object, Rectangle);
         if not Results.Succeeded (Outcome) then
            return Fail (Object, Outcome.First_Error);
         end if;
      end if;

      Pixel_Bytes := Byte_Count (Descriptor.Width) * Byte_Count (Descriptor.Height);
      if Pixel_Bytes > Byte_Count (Natural'Last) then
         return Fail (Object, Errors.Make (Errors.Integer_Overflow));
      elsif Object.Owned_Allocation_Bytes > Object.Constraints.Max_Allocation_Bytes
        or else Pixel_Bytes > Object.Constraints.Max_Allocation_Bytes - Object.Owned_Allocation_Bytes
      then
         return Fail
           (Object,
            Errors.Make
              (Errors.Limit_Exceeded,
               (Source => Object.Input.Offset,
                Frame => Object.Frames_Seen,
                Expected => Object.Constraints.Max_Allocation_Bytes,
                Actual => Object.Owned_Allocation_Bytes + Pixel_Bytes,
                Limit => Allocation_Byte_Limit,
                others => <>)));
      end if;
      begin
         Indices := new Streams.Byte_Array (1 .. Natural (Pixel_Bytes));
      exception
         when Storage_Error =>
            return Fail
              (Object,
               Errors.Make
                 (Errors.Limit_Exceeded,
                  (Source => Object.Input.Offset,
                   Frame => Object.Frames_Seen,
                   Expected => Object.Constraints.Max_Allocation_Bytes,
                   Actual => Object.Owned_Allocation_Bytes + Pixel_Bytes,
                   Limit => Allocation_Byte_Limit,
                   others => <>)));
      end;
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes + Pixel_Bytes;
      Outcome := Internal.Image_Data.Decode_Indices
        (Object.Input.all, Descriptor, Palette, Object.Constraints,
         Object.Total_Decoded_Pixels, Object.Total_Compressed_Bytes,
         Indices.all, Object.Frames_Seen);
      if not Results.Succeeded (Outcome) then
         Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes - Pixel_Bytes;
         Free_Bytes (Indices);
         return Fail (Object, Outcome.First_Error);
      end if;

      for Row in 0 .. Natural (Descriptor.Height) - 1 loop
         for Column in 0 .. Natural (Descriptor.Width) - 1 loop
            Index_Position := Row * Natural (Descriptor.Width) + Column;
            if not Control.Has_Transparency
              or else Palette_Index (Indices (Indices'First + Index_Position)) /= Control.Transparent_Index
            then
               Color := Palette.Colors (Palette_Index (Indices (Indices'First + Index_Position)));
               Canvas_Position :=
                 ((Natural (Descriptor.Top) + Row) * Natural (Object.Header_Data.Width)
                  + Natural (Descriptor.Left) + Column) * 4;
               Object.Canvas (Object.Canvas'First + Canvas_Position) := Color.Red;
               Object.Canvas (Object.Canvas'First + Canvas_Position + 1) := Color.Green;
               Object.Canvas (Object.Canvas'First + Canvas_Position + 2) := Color.Blue;
               Object.Canvas (Object.Canvas'First + Canvas_Position + 3) := 255;
            end if;
         end loop;
      end loop;
      Object.Owned_Allocation_Bytes := Object.Owned_Allocation_Bytes - Pixel_Bytes;
      Free_Bytes (Indices);
      Target := Object.Canvas.all;
      Info :=
        (Ordinal => Object.Frames_Seen,
         Left => Descriptor.Left,
         Top => Descriptor.Top,
         Width => Descriptor.Width,
         Height => Descriptor.Height,
         Interlaced => Descriptor.Interlaced,
         Has_Local_Palette => Descriptor.Has_Local_Palette,
         Local_Palette_Sorted => Descriptor.Local_Palette_Sorted,
         Effective_Palette => Palette,
         Control => Control);
      Object.Previous_Rectangle := Rectangle;
      Object.Previous_Control := Control;
      Object.Has_Previous_Frame := True;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Decode_Composited_Frame;

   function Skip_Frame (Object : in out Decoder) return Results.Result is
      Descriptor : Internal.Container.Image_Descriptor;
      Palette : Palettes.Palette;
      Minimum_Code_Size : Byte;
      Reader : Internal.Blocks.Sub_Block_Reader;
      Outcome : Results.Result;
   begin
      if Object.Current_State /= Awaiting_Frame_Decision or else Object.Input = null then
         return Invalid_Transition (Object);
      elsif Object.Options.Mode = Composited_RGBA then
         return Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               (Source => Object.Input.Offset, Frame => Object.Frames_Seen, others => <>)));
      end if;
      Outcome := Internal.Container.Read_Image_Descriptor
        (Object.Input.all,
         To_Internal_Header (Object.Header_Data),
         Object.Constraints,
         Descriptor,
         Palette,
         Separator_Already_Read => True);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Outcome := Internal.Bytes.Read_Byte (Object.Input.all, Minimum_Code_Size, Image_Data_Block);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      elsif Minimum_Code_Size < 2 or else Minimum_Code_Size > 8 then
         return Fail
           (Object,
            Errors.Make
              (Errors.LZW_Invalid_Minimum_Code_Size,
               (Source => Object.Input.Offset - 1,
                Block => Image_Data_Block,
                Frame => Object.Frames_Seen,
                Actual => Byte_Count (Minimum_Code_Size),
                others => <>)));
      end if;
      Internal.Blocks.Initialize
        (Reader,
         Object.Constraints.Max_Compressed_Bytes - Object.Total_Compressed_Bytes,
         Compressed_Byte_Limit,
         Image_Data_Block);
      Outcome := Internal.Blocks.Drain (Reader, Object.Input.all);
      Object.Total_Compressed_Bytes :=
        Object.Total_Compressed_Bytes + Internal.Blocks.Total_Bytes (Reader);
      if not Results.Succeeded (Outcome) then
         return Fail (Object, Outcome.First_Error);
      end if;
      Object.Frames_Seen := Object.Frames_Seen + 1;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Skip_Frame;

   function Cancel (Object : in out Decoder) return Results.Result is
   begin
      case Object.Current_State is
         when Initialized | Header_Ready | Awaiting_Frame_Decision | Decoding_Frame =>
            Release_Metadata (Object);
            Release_Images (Object);
            Object.Current_State := Cancelled;
            Object.Diagnostic := Errors.Make (Errors.Operation_Cancelled);
            return Results.Success;
         when Cancelled =>
            return Results.Success;
         when Failed =>
            return Results.Failure (Object.Diagnostic);
         when others =>
            return Invalid_Transition (Object);
      end case;
   end Cancel;

   function State (Object : Decoder) return Decoder_State is
   begin
      return Object.Current_State;
   end State;

   function First_Error (Object : Decoder) return Errors.Error is
   begin
      return Object.Diagnostic;
   end First_Error;

   function Warning_Count (Object : Decoder) return Natural is
   begin
      return Object.Stored_Warnings;
   end Warning_Count;

   function Warning_At
     (Object : Decoder;
      Index : Positive;
      Item : out Errors.Warning) return Results.Result
   is
   begin
      Item := Errors.Make_Warning (Errors.Generic_Warning, Errors.Informational);
      if Index > Object.Stored_Warnings then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Item := Object.Warnings (Index);
      return Results.Success;
   end Warning_At;

   function Looping (Object : Decoder) return Animations.Loop_Info is
   begin
      return Object.Loop_Data;
   end Looping;

   function Retained_Extension_Count (Object : Decoder) return Natural is
   begin
      return Object.Retained_Count;
   end Retained_Extension_Count;

   function Find_Node (Object : Decoder; Index : Positive) return Extension_Node_Access is
      Node : Extension_Node_Access := Object.Retained_First;
      Position : Positive := 1;
   begin
      while Node /= null and then Position < Index loop
         Node := Node.Next;
         Position := Position + 1;
      end loop;
      return Node;
   end Find_Node;

   function Retained_Extension_Info
     (Object : Decoder;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result
   is
      Node : constant Extension_Node_Access := Find_Node (Object, Index);
   begin
      Info := (others => <>);
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Info := Node.Info;
      return Results.Success;
   end Retained_Extension_Info;

   function Copy_Retained_Extension_Payload
     (Object : Decoder;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Node : constant Extension_Node_Access := Find_Node (Object, Index);
      Chunk : Payload_Chunk_Access;
      Position : Natural := 0;
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Byte_Count (Target'Length) < Node.Info.Payload_Length then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Node.Info.Payload_Length,
                Actual => Byte_Count (Target'Length),
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      Chunk := Node.First_Chunk;
      while Chunk /= null loop
         for I in 0 .. Chunk.Length - 1 loop
            Target (Target'First + Position) := Chunk.Data (Chunk.Data'First + I);
            Position := Position + 1;
         end loop;
         Chunk := Chunk.Next;
      end loop;
      Count := Byte_Count (Position);
      return Results.Success;
   end Copy_Retained_Extension_Payload;

   function Retained_Extension_Chunk_Count
     (Object : Decoder;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
      Node : constant Extension_Node_Access := Find_Node (Object, Index);
      Chunk : Payload_Chunk_Access;
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Chunk := Node.First_Chunk;
      while Chunk /= null loop
         Count := Count + 1;
         Chunk := Chunk.Next;
      end loop;
      return Results.Success;
   end Retained_Extension_Chunk_Count;

   function Copy_Retained_Extension_Chunk
     (Object : Decoder;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Node : constant Extension_Node_Access := Find_Node (Object, Index);
      Chunk : Payload_Chunk_Access;
      Position : Positive := 1;
   begin
      Count := 0;
      if Node = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      end if;
      Chunk := Node.First_Chunk;
      while Chunk /= null and then Position < Chunk_Index loop
         Chunk := Chunk.Next;
         Position := Position + 1;
      end loop;
      if Chunk = null then
         return Results.Failure (Errors.Make (Errors.Invalid_State));
      elsif Target'Length < Chunk.Length then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Chunk.Length),
                Actual => Byte_Count (Target'Length),
                Limit => Output_Byte_Limit,
                others => <>)));
      end if;
      for I in 0 .. Chunk.Length - 1 loop
         Target (Target'First + I) := Chunk.Data (Chunk.Data'First + I);
      end loop;
      Count := Byte_Count (Chunk.Length);
      return Results.Success;
   end Copy_Retained_Extension_Chunk;

   procedure Finalize (Object : in out Decoder) is
   begin
      Release_Metadata (Object);
      Release_Images (Object);
      Object.Input := null;
      Object.Header_Data := (others => <>);
      Object.Frames_Seen := 0;
      Object.Total_Decoded_Pixels := 0;
      Object.Total_Compressed_Bytes := 0;
      Object.Extensions_Seen := 0;
      Object.Pending_Control := Frames.Default_Control;
      Object.Has_Pending_Control := False;
      Object.Loop_Data := Animations.No_Loop;
      Object.Stored_Warnings := 0;
      Object.Current_State := Finalized;
   end Finalize;
end Giflib.Decoding;
