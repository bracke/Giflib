package body Giflib.Internal.LZW_Decoder_Dictionary is
   function Is_Initialized (Object : Dictionary) return Boolean is
     (Object.Initialized);

   function Is_Defined
     (Object : Dictionary;
      Index : Code_Index) return Boolean is
     (Object.Initialized
      and then Index >= Object.First_Dynamic
      and then Natural (Index) < Object.Next_Undefined);

   function Can_Define
     (Object : Dictionary;
      Index : Code_Index) return Boolean is
     (Object.Initialized and then Natural (Index) = Object.Next_Undefined);

   function Suffix_Is_Valid
     (Object : Dictionary;
      Suffix : Byte) return Boolean is
     (Object.Initialized and then Suffix <= Object.Maximum_Index);

   procedure Reset
     (Object : in out Dictionary;
      First_Dynamic_Code : Code_Index;
      Maximum_Index : Byte := Byte'Last) is
   begin
      Object.First_Dynamic := First_Dynamic_Code;
      Object.Next_Undefined := Natural (First_Dynamic_Code);
      Object.Maximum_Index := Maximum_Index;
      Object.Initialized := True;
   end Reset;

   function Entry_At
     (Object : Dictionary;
      Index : Code_Index) return Dictionary_Entry is
     (Prefix => Object.Prefixes (Index),
      Suffix => Object.Suffixes (Index));

   procedure Set_Entry
     (Object : in out Dictionary;
      Index : Code_Index;
      Prefix : Code_Index;
      Suffix : Byte) is
   begin
      Object.Prefixes (Index) := Prefix;
      Object.Suffixes (Index) := Suffix;
      Object.Next_Undefined := Natural (Index) + 1;
   end Set_Entry;

   function Stack_At
     (Object : Dictionary;
      Index : Stack_Index) return Byte is
     (Object.Stack (Index));

   procedure Set_Stack
     (Object : in out Dictionary;
      Index : Stack_Index;
      Value : Byte) is
   begin
      Object.Stack (Index) := Value;
   end Set_Stack;
end Giflib.Internal.LZW_Decoder_Dictionary;
