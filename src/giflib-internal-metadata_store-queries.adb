with Giflib.Errors;
with Giflib.Internal.Metadata_Store.Validation;

package body Giflib.Internal.Metadata_Store.Queries is
   use type Metadata.Extension_Kind;
   package Checks renames Giflib.Internal.Metadata_Store.Validation;

   function Info_At
     (Object : Store;
      Index : Positive;
      Info : out Metadata.Extension_Info) return Results.Result
   is
      Node : Extension_Node;
      Outcome : Results.Result;
   begin
      Outcome := Checks.Load_Node (Object, Index, Node);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Info'Constrained and then Info.Kind /= Node.Info.Kind then
         return Results.Failure
           (Errors.Make
              (Errors.Output_Variant_Mismatch,
               (Expected => Byte_Count (Metadata.Extension_Kind'Pos (Info.Kind)),
                Actual => Byte_Count
                  (Metadata.Extension_Kind'Pos (Node.Info.Kind)),
                others => <>)));
      end if;
      Info := Node.Info;
      return Results.Success;
   end Info_At;

   function Copy_Payload
     (Object : Store;
      Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Position : Natural := 0;
      Node : Extension_Node;
      Chunk : Payload_Chunk;
      Outcome : Results.Result;
   begin
      Count := 0;
      Outcome := Checks.Load_Node (Object, Index, Node);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Byte_Count (Target'Length) < Checks.Stored_Length (Node) then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Checks.Stored_Length (Node),
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      if Node.Span.Present then
         for Offset in 0 .. Node.Span.Count - 1 loop
            Chunk := Payload_Chunks.Element
              (Object.Chunks, Node.Span.First + Offset);
            if Chunk.Length > Target'Length - Position then
               return Checks.Invalid_Store;
            end if;
            for I in 0 .. Chunk.Length - 1 loop
               Target (Target'First + Position) :=
                 Chunk.Data (Chunk.Data'First + I);
               Position := Position + 1;
            end loop;
         end loop;
      end if;
      if Byte_Count (Position) /= Checks.Stored_Length (Node) then
         return Checks.Invalid_Store;
      end if;
      Count := Byte_Count (Position);
      return Results.Success;
   end Copy_Payload;

   function Chunk_Count
     (Object : Store;
      Index : Positive;
      Count : out Natural) return Results.Result
   is
      Node : Extension_Node;
      Outcome : Results.Result;
   begin
      Count := 0;
      Outcome := Checks.Load_Node (Object, Index, Node);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      Count := Checks.Stored_Chunk_Count (Node);
      return Results.Success;
   end Chunk_Count;

   function Copy_Chunk
     (Object : Store;
      Index : Positive;
      Chunk_Index : Positive;
      Target : out Streams.Byte_Array;
      Count : out Byte_Count) return Results.Result
   is
      Node : Extension_Node;
      Chunk : Payload_Chunk;
      Outcome : Results.Result;
   begin
      Count := 0;
      Outcome := Checks.Load_Node (Object, Index, Node);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;
      if Chunk_Index > Checks.Stored_Chunk_Count (Node) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Chunk := Payload_Chunks.Element
        (Object.Chunks, Node.Span.First + Chunk_Index - 1);
      if Target'Length < Chunk.Length then
         return Results.Failure
           (Errors.Make
              (Errors.Buffer_Size_Mismatch,
               (Expected => Byte_Count (Chunk.Length),
                Actual => Byte_Count (Target'Length), others => <>)));
      end if;
      for I in 0 .. Chunk.Length - 1 loop
         Target (Target'First + I) := Chunk.Data (Chunk.Data'First + I);
      end loop;
      Count := Byte_Count (Chunk.Length);
      return Results.Success;
   end Copy_Chunk;
end Giflib.Internal.Metadata_Store.Queries;
