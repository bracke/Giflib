with Giflib.Animations;
with Giflib.Encoding.State_Arithmetic;
with Giflib.Internal.Wire_Format;

package body Giflib.Encoding.Extensions is
   use type Animations.Loop_State;
   use type Metadata.Extension_Kind;
   function Write_Chunk
     (Object : in out Encoder;
      Payload : Streams.Byte_Array;
      Position : in out Natural;
      Length : Positive) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_Raw (Object, [1 => Byte (Length)]);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw
           (Object,
            Payload
              (Payload'First + Position
               .. Payload'First + Position + Length - 1));
      end if;
      if Results.Succeeded (Outcome) then
         Position := Position + Length;
      end if;
      return Outcome;
   end Write_Chunk;

   function Complete_Extension
     (Object : in out Encoder;
      Outcome : Results.Result) return Results.Result
   is
      Final_Outcome : Results.Result := Outcome;
   begin
      if Results.Succeeded (Final_Outcome) then
         Final_Outcome := Write_Raw (Object, [1 => 0]);
      end if;
      if not Results.Succeeded (Final_Outcome) then
         return Fail (Object, Final_Outcome.First_Error);
      end if;
      Object.Extensions_Written := Object.Extensions_Written + 1;
      State_Arithmetic.Transition (Object.Current_State, Accepting_Frames);
      return Results.Success;
   end Complete_Extension;

   function Write_Prefix
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Position : out Natural) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Position := 0;
      Outcome := Write_Raw
        (Object,
         [Internal.Wire_Format.Extension_Introducer,
          Metadata.Label_Of (Descriptor)]);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Fixed_Length > 0 then
         if Payload'Length < Fixed_Length then
            return Results.Failure (Errors.Make (Errors.Invalid_Extension));
         end if;
         Outcome := Write_Raw (Object, [1 => Byte (Fixed_Length)]);
         if Results.Succeeded (Outcome) then
            Outcome := Write_Raw
              (Object, Payload (Payload'First .. Payload'First + Fixed_Length - 1));
         end if;
         Position := Fixed_Length;
      end if;
      return Outcome;
   end Write_Prefix;

   function Validate
     (Object : Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : out Natural) return Results.Result
   is
      Additional_Extensions : constant Natural :=
        (if Object.Loop_Data.State /= Animations.No_Loop_Extension
             and then not Object.Header_Written
         then 2 else 1);
   begin
      Fixed_Length := 0;
      if not State_Arithmetic.Can_Accept_Data
        (Object.Current_State)
      then
         return Invalid_Transition (Object);
      elsif Object.Options.Version = Force_GIF87a then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      elsif not Has_Extension_Capacity
        (Object, Additional_Extensions)
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Written)
                  + Byte_Count (Additional_Extensions),
                Limit => Extension_Count_Limit,
                others => <>)));
      elsif Byte_Count (Payload'Length)
        > Object.Constraints.Max_Per_Extension_Bytes
      then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Expected => Object.Constraints.Max_Per_Extension_Bytes,
                Actual => Byte_Count (Payload'Length),
                Limit => Per_Extension_Byte_Limit, others => <>)));
      end if;
      case Descriptor.Kind is
         when Application_Extension =>
            Fixed_Length := 11;
         when Plain_Text_Extension =>
            Fixed_Length := 12;
         when Comment_Extension =>
            null;
         when Unknown_Extension =>
            if Metadata.Kind_Of (Descriptor.Label) /= Metadata.Unknown_Extension
            then
               return Results.Failure
                 (Errors.Make (Errors.Invalid_Extension));
            end if;
      end case;
      if Payload'Length < Fixed_Length then
         return Results.Failure (Errors.Make (Errors.Invalid_Extension));
      end if;
      return Results.Success;
   end Validate;

   function Add
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array) return Results.Result
   is
      Fixed_Length : Natural;
      Position : Natural;
      Chunk : Natural;
      Outcome : Results.Result;
   begin
      Outcome := Validate (Object, Descriptor, Payload, Fixed_Length);
      if not Results.Succeeded (Outcome) then
         return Reject_Request (Object, Outcome.First_Error);
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Prefix
           (Object, Descriptor, Payload, Fixed_Length, Position);
      end if;
      while Results.Succeeded (Outcome) and then Position < Payload'Length loop
         Chunk := Natural'Min (255, Payload'Length - Position);
         Outcome := Write_Chunk
           (Object, Payload, Position, Positive (Chunk));
      end loop;
      return Complete_Extension (Object, Outcome);
   end Add;

   function Add_Exact
     (Object : in out Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Chunk_Lengths : Chunk_Length_Array) return Results.Result
   is
      Fixed_Length : Natural;
      Position : Natural := 0;
      Sum : Byte_Count := 0;
      Outcome : Results.Result;
   begin
      Outcome := Validate (Object, Descriptor, Payload, Fixed_Length);
      if not Results.Succeeded (Outcome) then
         return Reject_Request (Object, Outcome.First_Error);
      end if;
      if Chunk_Lengths'Length > Payload'Length
        or else (Fixed_Length > 0
                 and then (Chunk_Lengths'Length = 0
                           or else Chunk_Lengths (Chunk_Lengths'First)
                             /= Fixed_Length))
      then
         return Reject_Request
           (Object, Errors.Make (Errors.Invalid_Extension));
      end if;
      for Length of Chunk_Lengths loop
         if Byte_Count (Length) > Byte_Count (Payload'Length) - Sum then
            return Reject_Request
              (Object, Errors.Make (Errors.Invalid_Extension));
         end if;
         Sum := Sum + Byte_Count (Length);
      end loop;
      if Sum /= Byte_Count (Payload'Length) then
         return Reject_Request
           (Object, Errors.Make (Errors.Invalid_Extension));
      end if;
      Outcome := Write_Header (Object);
      if Results.Succeeded (Outcome) then
         Outcome := Write_Raw
           (Object,
            [Internal.Wire_Format.Extension_Introducer,
             Metadata.Label_Of (Descriptor)]);
      end if;
      for Length of Chunk_Lengths loop
         exit when not Results.Succeeded (Outcome);
         Outcome := Write_Chunk (Object, Payload, Position, Length);
      end loop;
      return Complete_Extension (Object, Outcome);
   end Add_Exact;
end Giflib.Encoding.Extensions;
