with Giflib.Encoding.State_Arithmetic;
with Giflib.Encoding.Failure_Handling;
with Giflib.Encoding.Frame_Preparation;
with Giflib.Encoding.Frame_Sources;
with Giflib.Encoding.Frame_Transaction;
with Giflib.Internal.Geometry_Arithmetic;

package body Giflib.Encoding.Frame_Pipeline is
   package Geometry_Arithmetic renames Internal.Geometry_Arithmetic;

   generic
      type Source_Type (<>) is private;
      with function Source_Length (Source : Source_Type) return Byte_Count;
      with function Encode_Source
        (Object : in out Encoder;
         Info : Frame_Info;
         Source : Source_Type;
         Minimum : Byte;
         Maximum_Index : Byte;
         Compressed : out Byte_Count;
         Wire_Bytes : out Byte_Count) return Results.Result;
   function Add_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Source : Source_Type) return Results.Result;

   function Add_Frame
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Source : Source_Type) return Results.Result
   is
      Required : constant Byte_Count :=
        Geometry_Arithmetic.Area (Info.Width, Info.Height);
      Pixel_Count : constant Byte_Count := Source_Length (Source);
      Data : Frame_Preparation.Prepared_Frame_Request;
      Outcome : Results.Result;
      Compressed : Byte_Count;
      Wire_Bytes : Byte_Count;
   begin
      if not State_Arithmetic.Can_Accept_Data (Object.Current_State) then
         return Failure_Handling.Invalid_State (Object);
      elsif Pixel_Count /= Required then
         return Failure_Handling.Reject_Frame
           (Object, Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Required, Actual => Pixel_Count, others => <>)));
      end if;
      Outcome := Frame_Preparation.Validate (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Frame_Transaction.Commit_Prefix (Object, Info, Palette, Data);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Outcome := Encode_Source
        (Object, Info, Source, Data.Minimum,
         Byte (Data.Effective.Length - 1), Compressed, Wire_Bytes);
      return Frame_Transaction.Complete
        (Object, Outcome, Compressed, Wire_Bytes);
   end Add_Frame;

   function Add_Indexed_Source is new Add_Frame
     (Source_Type => Streams.Byte_Array,
      Source_Length => Frame_Sources.Indexed_Length,
      Encode_Source => Frame_Sources.Encode_Indexed);

   function Add_Stored_Source is new Add_Frame
     (Source_Type => Byte_Count,
      Source_Length => Frame_Sources.Stored_Length,
      Encode_Source => Frame_Sources.Encode_Stored);

   function Add_Indexed
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixels : Streams.Byte_Array) return Results.Result
   is
   begin
      return Add_Indexed_Source (Object, Info, Palette, Pixels);
   end Add_Indexed;

   function Add_Stored
     (Object : in out Encoder;
      Info : Frame_Info;
      Palette : Frame_Palette;
      Pixel_Count : Byte_Count) return Results.Result
   is
   begin
      return Add_Stored_Source (Object, Info, Palette, Pixel_Count);
   end Add_Stored;
end Giflib.Encoding.Frame_Pipeline;
