with Giflib.Internal.Decoder_Storage.Metadata_Operations;

package body Giflib.Decoding.Extensions.Retention is
   function Start
     (Object : in out Decoder;
      Info : Metadata.Extension_Info) return Results.Result is
     (Internal.Decoder_Storage.Metadata_Operations.Start
        (Object.Resources,
         Object.Allocation_Fault,
         Object.Options.Retention,
         Object.Constraints.Max_Allocation_Bytes,
         Info));

   function Append
     (Object : in out Decoder;
      Data : Streams.Byte_Array) return Results.Result is
     (Internal.Decoder_Storage.Metadata_Operations.Append
        (Object.Resources,
         Object.Allocation_Fault,
         Data,
         Object.Constraints.Max_Retained_Metadata_Bytes,
         Object.Constraints.Max_Allocation_Bytes));

   function Finish
     (Object : in out Decoder;
      Info : Metadata.Extension_Info) return Results.Result is
     (Internal.Decoder_Storage.Metadata_Operations.Finish
        (Object.Resources, Info));
end Giflib.Decoding.Extensions.Retention;
