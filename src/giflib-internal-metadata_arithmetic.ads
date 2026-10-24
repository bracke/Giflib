with Giflib.Metadata;

package Giflib.Internal.Metadata_Arithmetic
  with Pure, SPARK_Mode
is
   use type Metadata.Extension_Kind;

   function Classify (Label : Byte) return Metadata.Extension_Kind
     with Post =>
       Classify'Result =
         (case Label is
             when 16#F9# => Metadata.Graphic_Control_Extension,
             when 16#FE# => Metadata.Comment_Extension,
             when 16#01# => Metadata.Plain_Text_Extension,
             when 16#FF# => Metadata.Application_Extension,
             when others => Metadata.Unknown_Extension);

   function Block_For (Kind : Metadata.Extension_Kind) return Block_Kind
     with Post =>
       Block_For'Result =
         (case Kind is
             when Metadata.Graphic_Control_Extension => Graphic_Control_Extension_Block,
             when Metadata.Comment_Extension => Comment_Extension_Block,
             when Metadata.Plain_Text_Extension => Plain_Text_Extension_Block,
             when Metadata.Application_Extension => Application_Extension_Block,
             when Metadata.Unknown_Extension => Unknown_Extension_Block);

   function Should_Retain
     (Policy : Metadata.Retention_Policy;
      Kind : Metadata.Extension_Kind) return Boolean
     with Post =>
       Should_Retain'Result =
         (case Policy is
             when Metadata.Discard_All
                | Metadata.Parse_Known_Without_Retention => False,
             when Metadata.Retain_Selected =>
               Kind in Metadata.Comment_Extension
                     | Metadata.Application_Extension,
             when Metadata.Retain_All_Bounded
                | Metadata.Retain_All_Exact_Bounded => True);

   function Can_Append
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Length : Natural) return Boolean
     with Post =>
       Can_Append'Result =
         (Current <= Maximum
          and then Byte_Count (Length) <= Maximum - Current);

   function Appended_Length
     (Current : Byte_Count;
      Maximum : Byte_Count;
      Length : Natural) return Byte_Count
     with Pre => Can_Append (Current, Maximum, Length),
          Post =>
            Appended_Length'Result = Current + Byte_Count (Length)
            and then Appended_Length'Result <= Maximum;

   function Can_Increment (Value : Natural) return Boolean is
     (Value < Natural'Last);

   function Increment (Value : Natural) return Natural
     with Pre => Can_Increment (Value),
          Post => Increment'Result = Value + 1;
end Giflib.Internal.Metadata_Arithmetic;
