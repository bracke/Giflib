with AUnit.Assertions;

with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Frames;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Giflib.Testing.Assertions;

package body Giflib.Testing.Test_Policy is
   use AUnit.Assertions;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Warning_Code;
   use type Giflib.Frames.Disposal_Method;
   use type Giflib.Streams.Byte_Array;

   type Overreporting_Source
     (Storage : not null access constant Giflib.Streams.Byte_Array)
      is limited new Giflib.Streams.Source with record
      Backing : Giflib.Streams.Memory_Source (Storage);
   end record;

   overriding function Read
     (Object : in out Overreporting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Overreporting_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Overreporting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Image_Descriptor_Reserved_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("policy");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Trailing_Data_Policy'Access, "policy.trailing_data");
      Register_Routine (T, Safe_Missing_Trailer_Recovery'Access, "policy.safe_truncation");
      Register_Routine (T, Duplicate_And_Reserved_Policy'Access, "policy.duplicate_and_reserved");
      Register_Routine
        (T,
         Image_Descriptor_Reserved_Policy'Access,
         "policy.image_descriptor_reserved");
   end Register_Tests;

   function Base_GIF (Trailer : Boolean := True) return Giflib.Streams.Byte_Array is
      Prefix : constant Giflib.Streams.Byte_Array :=
        [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0,
         0, 0, 0, 255, 255, 255,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 1, 0];
   begin
      if Trailer then
         return Prefix & [16#3B#];
      end if;
      return Prefix;
   end Base_GIF;

   overriding function Read
     (Object : in out Overreporting_Source;
      Buffer : out Giflib.Streams.Byte_Array) return Giflib.Streams.Source_Result
   is
      Step : Giflib.Streams.Source_Result := Object.Backing.Read (Buffer);
   begin
      if Step.Count = 0 and then Step.End_Of_Input then
         Step.Count := 2;
         Step.End_Of_Input := False;
      end if;
      return Step;
   end Read;

   overriding function Offset
     (Object : Overreporting_Source) return Giflib.Source_Offset is
   begin
      return Object.Backing.Offset;
   end Offset;

   overriding function Skip
     (Object : in out Overreporting_Source;
      Count : Giflib.Byte_Count) return Giflib.Streams.Source_Result is
   begin
      return Object.Backing.Skip (Count);
   end Skip;

   procedure Reach_End
     (Decoder : in out Giflib.Decoding.Decoder;
      Pixel : out Giflib.Streams.Byte_Array;
      Outcome : out Giflib.Results.Result)
   is
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
   begin
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Decode_Indexed_Frame (Decoder, Pixel, Info);
      end if;
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      end if;
   end Reach_End;

   procedure Trailing_Data_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Safe_Missing_Trailer_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Duplicate_And_Reserved_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Image_Descriptor_Reserved_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;
end Giflib.Testing.Test_Policy;
