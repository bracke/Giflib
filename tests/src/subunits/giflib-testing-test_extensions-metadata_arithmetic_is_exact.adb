separate (Giflib.Testing.Test_Extensions)
procedure Metadata_Arithmetic_Is_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   package Arithmetic renames Giflib.Internal.Metadata_Arithmetic;
begin
   Assert
     (Giflib.Metadata.Kind_Of (16#F9#) = Giflib.Metadata.Graphic_Control_Extension
      and then Giflib.Metadata.Kind_Of (16#FE#) = Giflib.Metadata.Comment_Extension
      and then Giflib.Metadata.Kind_Of (16#01#) = Giflib.Metadata.Plain_Text_Extension
      and then Giflib.Metadata.Kind_Of (16#FF#) = Giflib.Metadata.Application_Extension
      and then Giflib.Metadata.Kind_Of (16#02#) = Giflib.Metadata.Unknown_Extension
      and then Giflib.Metadata.Label_Of
        (Giflib.Metadata.Comment_Extension) = 16#FE#
      and then Giflib.Metadata.Label_Of
        (Giflib.Metadata.Extension_Descriptor'
           (Kind => Giflib.Metadata.Unknown_Extension,
            Label => 16#02#)) = 16#02#,
      "extension label classification is wrong");
   Assert
     (Arithmetic.Block_For (Giflib.Metadata.Comment_Extension)
        = Giflib.Comment_Extension_Block
      and then Arithmetic.Should_Retain
        (Giflib.Metadata.Retain_Selected, Giflib.Metadata.Comment_Extension)
      and then not Arithmetic.Should_Retain
        (Giflib.Metadata.Retain_Selected, Giflib.Metadata.Plain_Text_Extension),
      "metadata retention classification is wrong");
   Assert
     (Arithmetic.Can_Append (Giflib.Byte_Count'Last - 1,
                             Giflib.Byte_Count'Last, 1)
      and then Arithmetic.Appended_Length
        (Giflib.Byte_Count'Last - 1, Giflib.Byte_Count'Last, 1)
          = Giflib.Byte_Count'Last
      and then Arithmetic.Increment (Natural'Last - 1) = Natural'Last,
      "metadata count accounting is wrong");
end Metadata_Arithmetic_Is_Exact;
