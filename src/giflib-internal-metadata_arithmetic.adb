package body Giflib.Internal.Metadata_Arithmetic
  with SPARK_Mode
is
   function Classify (Label : Byte) return Metadata.Extension_Kind is
     (case Label is
         when 16#F9# => Metadata.Graphic_Control_Extension,
         when 16#FE# => Metadata.Comment_Extension,
         when 16#01# => Metadata.Plain_Text_Extension,
         when 16#FF# => Metadata.Application_Extension,
         when others => Metadata.Unknown_Extension);

   function Block_For (Kind : Metadata.Extension_Kind) return Block_Kind is
     (case Kind is
         when Metadata.Graphic_Control_Extension => Graphic_Control_Extension_Block,
         when Metadata.Comment_Extension => Comment_Extension_Block,
         when Metadata.Plain_Text_Extension => Plain_Text_Extension_Block,
         when Metadata.Application_Extension => Application_Extension_Block,
         when Metadata.Unknown_Extension => Unknown_Extension_Block);

   function Should_Retain
     (Policy : Metadata.Retention_Policy;
      Kind : Metadata.Extension_Kind) return Boolean
   is
     (case Policy is
         when Metadata.Discard_All
            | Metadata.Parse_Known_Without_Retention => False,
         when Metadata.Retain_Selected =>
           Kind in Metadata.Comment_Extension | Metadata.Application_Extension,
         when Metadata.Retain_All_Bounded
            | Metadata.Retain_All_Exact_Bounded => True);

   function Can_Append
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Length : Natural) return Boolean
   is
     (Current <= Maximum
      and then Byte_Count (Length) <= Maximum - Current);

   function Appended_Length
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Length : Natural) return Byte_Count
   is
      pragma Unreferenced (Maximum);
   begin
      return Current + Byte_Count (Length);
   end Appended_Length;

   function Increment (Value : Natural) return Natural is (Value + 1);
end Giflib.Internal.Metadata_Arithmetic;
