with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Query_Testing;
with Giflib_Tooling.Session_Iterable_Test_Support;
with Giflib_Tooling.Session_Types;

package body Giflib_Tooling.Session_Iterable_Qualified_Tests is
   use Giflib_Tooling.Session_Iterable_Test_Support;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Queries renames Giflib_Tooling.Session_Query_Testing;
   package Semantics renames Giflib_Tooling.Session_Types;

   procedure Run is
   begin
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "package Short renames Provider; " &
              "function Sessions return Decoder_Array;",
              Identity.Create_Known ("Decoder"), Empty, "giflib.provider");
      begin
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of Provider.Sessions loop " &
               "Use (Item); end loop; end P;", Parent),
            "qualified callable results define iterator types");
         Check.Check
           (Has_Item
              ("procedure P is type Natural_Array is array " &
               "(Positive range <>) of Natural; Values : Natural_Array; " &
               "function Sessions return Natural_Array is (Values); begin " &
               "for Item of Provider.Sessions loop Use (Item); end loop; " &
               "end P;", Parent),
            "local homonyms do not hide qualified callable results");
         Check.Check
           (not Has_Item
              ("procedure P is begin for Item of Other.Sessions loop " &
               "Use (Item); end loop; end P;", Parent),
            "unrelated qualifiers do not borrow callable results");
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of Short.Sessions loop " &
               "Use (Item); end loop; end P;", Parent),
            "inherited package aliases retain callable identity");
         Check.Check
           (Has_Item
              ("procedure P is package Local renames Provider; begin " &
               "for Item of Local.Sessions loop Use (Item); end loop; end P;",
               Parent),
            "local package aliases retain callable identity");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Holder is record Items : Decoder_Array; end record; " &
              "function Get_Holder (Value : Natural) return Holder;",
              Identity.Create_Known ("Decoder"), Empty, "provider");
      begin
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of " &
               "Provider.Get_Holder (1).Items loop Use (Item); end loop; " &
               "end P;", Parent),
            "callable-result selections preserve component relations");
         Check.Check
           (Has_Item
              ("procedure P is Value : Provider.Holder; begin for Item of " &
               "Value.Items loop Use (Item); end loop; end P;", Parent),
            "selected record types preserve qualified component ownership");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Base is record Items : Decoder_Array; end record; " &
              "type Derived is new Base;",
              Identity.Create_Known ("Decoder"), Empty, "provider");
      begin
         Check.Check
           (Has_Item
              ("procedure P is type Base is null record; " &
               "Value : Provider.Derived; begin for Item of Value.Items " &
               "loop Use (Item); end loop; end P;", Parent),
            "qualified parent links resist local terminal-name shadowing");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Natural_Array is array (Positive range <>) of Natural; " &
              "function Copy (Value : Decoder_Array) return Decoder_Array; " &
              "function Copy (Value : Natural_Array) return Natural_Array;",
              Identity.Create_Known ("Decoder"), Empty);
      begin
         Check.Check
           (not Has_Item
              ("procedure P is Values : Natural_Array; begin " &
               "for Item of Copy (Values) loop Use (Item); end loop; end P;",
               Parent),
            "same-arity overloads use formal and actual types");
         Check.Check
           (Has_Item
              ("procedure P is Values : Decoder_Array; begin " &
               "for Item of Copy (Values) loop Use (Item); end loop; end P;",
               Parent),
            "typed overload selection retains session results");
      end;
   end Run;
end Giflib_Tooling.Session_Iterable_Qualified_Tests;
