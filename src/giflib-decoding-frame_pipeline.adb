with Giflib.Decoding.Frame_Execution;
with Giflib.Decoding.Frame_Lifecycle;

package body Giflib.Decoding.Frame_Pipeline is
   function Prepare (Object : in out Decoder) return Results.Result is
     (Frame_Lifecycle.Prepare (Object));

   function Finish
     (Object : in out Decoder;
      Info : out Frame_Info) return Results.Result is
     (Frame_Lifecycle.Finish (Object, Info));

   function Start_Decode
     (Object : in out Decoder;
      Required_Mode : Output_Mode;
      Target_Length : Byte_Count;
      Info_Is_Constrained : Boolean;
      Info_Has_Local_Palette : Boolean) return Results.Result is
     (Frame_Lifecycle.Start_Decode
        (Object, Required_Mode, Target_Length,
         Info_Is_Constrained, Info_Has_Local_Palette));

   function Start_Skip (Object : in out Decoder) return Results.Result is
     (Frame_Lifecycle.Start_Skip (Object));

   function Decode_Indices
     (Object : in out Decoder;
      Output : out Streams.Byte_Array) return Results.Result is
     (Frame_Execution.Decode_Indices (Object, Output));

   function Composite
     (Object : in out Decoder;
      Target : out Streams.Byte_Array) return Results.Result is
     (Frame_Execution.Composite (Object, Target));

   function Skip_Data (Object : in out Decoder) return Results.Result is
     (Frame_Execution.Skip_Data (Object));
end Giflib.Decoding.Frame_Pipeline;
