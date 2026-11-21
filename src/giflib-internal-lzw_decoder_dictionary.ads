with Giflib.Internal.LZW_Arithmetic;

package Giflib.Internal.LZW_Decoder_Dictionary
  with Preelaborate
is
   pragma Warnings
     (Off, "aspect * not enforced on inlined subprogram *");
   subtype Code_Index is Natural range
     0 .. LZW_Arithmetic.Dictionary_Size - 1;
   subtype Stack_Index is Code_Index;

   type Dictionary is limited private;
   type Dictionary_Entry is record
      Prefix : Code_Index;
      Suffix : Byte;
   end record;

   function Is_Initialized (Object : Dictionary) return Boolean;
   function Is_Defined
     (Object : Dictionary;
      Index : Code_Index) return Boolean;
   function Can_Define
     (Object : Dictionary;
      Index : Code_Index) return Boolean;
   function Suffix_Is_Valid
     (Object : Dictionary;
      Suffix : Byte) return Boolean;
   procedure Reset
     (Object : in out Dictionary;
      First_Dynamic_Code : Code_Index;
      Maximum_Index : Byte := Byte'Last)
     with Post => Is_Initialized (Object)
                  and then not Is_Defined (Object, First_Dynamic_Code);

   function Entry_At
     (Object : Dictionary;
      Index : Code_Index) return Dictionary_Entry
     with Pre => Is_Defined (Object, Index);
   procedure Set_Entry
     (Object : in out Dictionary;
      Index : Code_Index;
      Prefix : Code_Index;
      Suffix : Byte)
     with Pre => Can_Define (Object, Index)
                   and then Suffix_Is_Valid (Object, Suffix),
          Post => Is_Defined (Object, Index);

   function Stack_At
     (Object : Dictionary;
      Index : Stack_Index) return Byte;
   procedure Set_Stack
     (Object : in out Dictionary;
      Index : Stack_Index;
      Value : Byte);

   pragma Inline_Always (Is_Defined);
   pragma Inline_Always (Can_Define);
   pragma Inline_Always (Suffix_Is_Valid);
   pragma Inline_Always (Entry_At);
   pragma Inline_Always (Set_Entry);
   pragma Inline_Always (Stack_At);
   pragma Inline_Always (Set_Stack);
   pragma Warnings
     (On, "aspect * not enforced on inlined subprogram *");

private
   type Prefix_Table is array (Code_Index) of Code_Index;
   type Byte_Table is array (Code_Index) of Byte;
   type Dictionary is limited record
      Prefixes : Prefix_Table := [others => 0];
      Suffixes : Byte_Table := [others => 0];
      Stack : Byte_Table := [others => 0];
      First_Dynamic : Code_Index := 0;
      Next_Undefined : Natural range 0 .. LZW_Arithmetic.Dictionary_Size := 0;
      Maximum_Index : Byte := Byte'Last;
      Initialized : Boolean := False;
   end record;
end Giflib.Internal.LZW_Decoder_Dictionary;
