separate (Giflib.Testing.Test_Container)
procedure Rejects_Signatures_And_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Bad_Signature : aliased constant Giflib.Streams.Byte_Array :=
     [66, 65, 68, 56, 57, 97, 1, 0, 1, 0, 0, 0, 0];
   Bad_Version : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 57, 48, 97, 1, 0, 1, 0, 0, 0, 0];
   Short_Palette : aliased constant Giflib.Streams.Byte_Array :=
     [71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 16#80#, 0, 0, 1, 2];
   Source : Giflib.Streams.Memory_Source (Bad_Signature'Access);
   Version_Source : Giflib.Streams.Memory_Source (Bad_Version'Access);
   Palette_Source : Giflib.Streams.Memory_Source (Short_Palette'Access);
   Header : Giflib.Internal.Container.Header_Info;
   Outcome : Giflib.Results.Result;
begin
   Giflib.Streams.Open (Source);
   Outcome := Giflib.Internal.Container.Read_Header (Source, Giflib.Limits.Default_Limits, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Signature, "bad signature was accepted");

   Giflib.Streams.Open (Version_Source);
   Outcome := Giflib.Internal.Container.Read_Header
     (Version_Source, Giflib.Limits.Default_Limits, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Invalid_Version, "bad version was accepted");

   Giflib.Streams.Open (Palette_Source);
   Outcome := Giflib.Internal.Container.Read_Header
     (Palette_Source, Giflib.Limits.Default_Limits, Header);
   Assert (Outcome.First_Error.Code = Giflib.Errors.Truncated_Block, "truncated palette has wrong error");
   Assert (Outcome.First_Error.Context.Block = Giflib.Global_Color_Table_Block,
           "truncated palette lost block context");
end Rejects_Signatures_And_Truncation;
