with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Wire_Format;

package body Giflib.Internal.Loop_Extensions is
   use type Metadata.Application_Authentication_Code;
   use type Metadata.Application_Identifier;

   function Is_Loop_Application
     (Identifier : Metadata.Application_Identifier;
      Authentication : Metadata.Application_Authentication_Code)
      return Boolean
   is
     ((Identifier = Netscape_Identifier
       and then Authentication = Netscape_Authentication)
      or else
      (Identifier = Animexts_Identifier
       and then Authentication = Animexts_Authentication));

   function Encode_Netscape
     (Count : Loop_Count_Value) return Encoded_Loop_Block
   is
     [Wire_Format.Extension_Introducer, Wire_Format.Application_Label, 11,
      Netscape_Identifier (1), Netscape_Identifier (2),
      Netscape_Identifier (3), Netscape_Identifier (4),
      Netscape_Identifier (5), Netscape_Identifier (6),
      Netscape_Identifier (7), Netscape_Identifier (8),
      Netscape_Authentication (1), Netscape_Authentication (2),
      Netscape_Authentication (3),
      3, 1,
      Extension_Arithmetic.Low_Byte (Count),
      Extension_Arithmetic.High_Byte (Count),
      0];
end Giflib.Internal.Loop_Extensions;
