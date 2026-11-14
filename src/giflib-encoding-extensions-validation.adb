with Giflib.Animations;
with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Request_Validation;
with Giflib.Encoding.State_Arithmetic;

package body Giflib.Encoding.Extensions.Validation is
   use type Animations.Loop_State;
   use type Metadata.Extension_Kind;

   function Request
     (Object : Encoder;
      Descriptor : Extension_Descriptor;
      Payload : Streams.Byte_Array;
      Fixed_Length : out Natural) return Results.Result
   is
      Additional_Extensions : constant Natural :=
        (if Object.Loop_Data.State /= Animations.No_Loop_Extension
             and then Object.Current_State = Screen_Defined
         then 2 else 1);
   begin
      Fixed_Length := 0;
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      elsif Object.Options.Version = Force_GIF87a then
         return Results.Failure (Errors.Make (Errors.Unsupported_Feature));
      elsif not Request_Validation.Has_Extension_Room
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
                Limit => Per_Extension_Byte_Limit,
                others => <>)));
      end if;
      case Descriptor.Kind is
         when Application_Extension =>
            Fixed_Length := 11;
         when Plain_Text_Extension =>
            Fixed_Length := 12;
         when Comment_Extension =>
            null;
         when Unknown_Extension =>
            if Metadata.Kind_Of (Descriptor.Label) /=
              Metadata.Unknown_Extension
            then
               return Results.Failure
                 (Errors.Make (Errors.Invalid_Extension));
            end if;
      end case;
      if Payload'Length < Fixed_Length then
         return Results.Failure (Errors.Make (Errors.Invalid_Extension));
      end if;
      return Results.Success;
   end Request;

   function Chunking
     (Payload : Streams.Byte_Array;
      Fixed_Length : Natural;
      Plan : Chunk_Plan) return Results.Result
   is
      Sum : Byte_Count := 0;
   begin
      if Plan.Kind = Automatic_Chunks then
         return Results.Success;
      elsif Plan.Count > Payload'Length
        or else (Fixed_Length > 0
                 and then (Plan.Count = 0
                           or else Plan.Lengths (1) /= Fixed_Length))
      then
         return Results.Failure (Errors.Make (Errors.Invalid_Extension));
      end if;
      for Length of Plan.Lengths loop
         if Byte_Count (Length) > Byte_Count (Payload'Length) - Sum then
            return Results.Failure (Errors.Make (Errors.Invalid_Extension));
         end if;
         Sum := Sum + Byte_Count (Length);
      end loop;
      return
        (if Sum = Byte_Count (Payload'Length)
         then Results.Success
         else Results.Failure (Errors.Make (Errors.Invalid_Extension)));
   end Chunking;
end Giflib.Encoding.Extensions.Validation;
