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

   procedure Reset
     (Object : in out Dictionary;
      First_Dynamic_Code : Code_Index) is
   begin
      Object.First_Dynamic := First_Dynamic_Code;
      Object.Next_Undefined := Natural (First_Dynamic_Code);
      Object.Initialized := True;
   end Reset;

   function Prefix_At
     (Object : Dictionary;
      Index : Code_Index) return Code_Index is
     (Object.Prefixes (Index));

   function Suffix_At
     (Object : Dictionary;
      Index : Code_Index) return Byte is
     (Object.Suffixes (Index));

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
