with Giflib.Errors;

package body Giflib.Internal.Metadata_Store.Validation is
   function Invalid_Store return Results.Result is
     (Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed)));

   function Span_Is_Valid
     (Object : Store; Node : Extension_Node) return Boolean
   is
      Total : constant Natural := Payload_Chunks.Length (Object.Chunks);
   begin
      if not Node.Span.Present then
         return True;
      elsif Node.Span.First > Total then
         return False;
      end if;
      return Node.Span.Count <= Total - Node.Span.First + 1;
   end Span_Is_Valid;

   function Stored_Length (Node : Extension_Node) return Byte_Count is
     (if Node.Span.Present then Node.Span.Length else 0);

   function Stored_Chunk_Count (Node : Extension_Node) return Natural is
     (if Node.Span.Present then Node.Span.Count else 0);

   function Node_Is_Valid
     (Object : Store; Index : Positive; Node : Extension_Node) return Boolean
   is
      Is_Pending : constant Boolean :=
        Object.Pending.State = Building and then Object.Pending.Index = Index;
   begin
      return Span_Is_Valid (Object, Node)
        and then
          (Is_Pending
           or else
             (Node.Info.Payload_Length = Stored_Length (Node)
              and then Node.Info.Sub_Block_Count = Stored_Chunk_Count (Node)));
   end Node_Is_Valid;

   function Load_Node
     (Object : Store;
      Index : Positive;
      Node : out Extension_Node) return Results.Result
   is
   begin
      if Index > Extension_Nodes.Length (Object.Entries) then
         return Results.Failure (Errors.Make (Errors.Invalid_Index));
      end if;
      Node := Extension_Nodes.Element (Object.Entries, Index);
      if not Node_Is_Valid (Object, Index, Node) then
         return Invalid_Store;
      end if;
      return Results.Success;
   end Load_Node;
end Giflib.Internal.Metadata_Store.Validation;
