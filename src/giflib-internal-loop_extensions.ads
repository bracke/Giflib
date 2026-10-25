with Giflib.Metadata;
with Giflib.Streams;

package Giflib.Internal.Loop_Extensions is
   pragma Preelaborate;

   Netscape_Identifier : constant Metadata.Application_Identifier :=
     [Character'Pos ('N'), Character'Pos ('E'), Character'Pos ('T'),
      Character'Pos ('S'), Character'Pos ('C'), Character'Pos ('A'),
      Character'Pos ('P'), Character'Pos ('E')];
   Netscape_Authentication : constant Metadata.Application_Authentication_Code :=
     [Character'Pos ('2'), Character'Pos ('.'), Character'Pos ('0')];
   Animexts_Identifier : constant Metadata.Application_Identifier :=
     [Character'Pos ('A'), Character'Pos ('N'), Character'Pos ('I'),
      Character'Pos ('M'), Character'Pos ('E'), Character'Pos ('X'),
      Character'Pos ('T'), Character'Pos ('S')];
   Animexts_Authentication : constant Metadata.Application_Authentication_Code :=
     [Character'Pos ('1'), Character'Pos ('.'), Character'Pos ('0')];

   function Is_Loop_Application
     (Identifier : Metadata.Application_Identifier;
      Authentication : Metadata.Application_Authentication_Code)
      return Boolean;

   subtype Encoded_Loop_Block is Streams.Byte_Array (1 .. 19);
   subtype Loop_Count_Value is Natural range 0 .. 65_535;
   function Encode_Netscape
     (Count : Loop_Count_Value) return Encoded_Loop_Block;
end Giflib.Internal.Loop_Extensions;
