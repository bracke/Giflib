with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Query_Testing;
with Giflib_Tooling.Session_Iterable_Test_Support;
with Giflib_Tooling.Session_Types;

package body Giflib_Tooling.Session_Iterable_Inheritance_Tests is
   use Ada.Strings.Unbounded;
   use Giflib_Tooling.Session_Iterable_Test_Support;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Queries renames Giflib_Tooling.Session_Query_Testing;
   package Semantics renames Giflib_Tooling.Session_Types;
   use type Semantics.Session_Depth;
   use type Semantics.Classification_Kind;

   procedure Run is
   begin
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("subtype Alias is Decoder;", Identity.Create_Known ("Decoder"),
              Empty);
         Child : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("subtype Alias is Natural;", Identity.Create_Known ("Decoder"),
              Parent);
         Alias_Depth : Semantics.Session_Depth := Semantics.Direct_Session;
      begin
         for Item of Child loop
            if To_String (Item.Name) = "alias" then
               Alias_Depth := Semantics.Relation_Of (Item).Depth;
            end if;
         end loop;
         Check.Check
           (Alias_Depth = Semantics.No_Session_Depth,
            "non-session descendant types shadow inherited session types");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("subtype Item is Decoder;", Identity.Create_Known ("Decoder"),
              Empty);
         Child : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("package Item renames Provider;",
              Identity.Create_Known ("Decoder"), Parent);
         Grandchild : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("subtype Item is Natural;", Identity.Create_Known ("Decoder"),
              Child);
         Direct_Count : Natural := 0;
         Is_Type : Boolean := False;
      begin
         for Item of Grandchild loop
            if To_String (Item.Name) = "item"
              and then Item.Kind /= Semantics.Component_Relation
            then
               Direct_Count := Direct_Count + 1;
               Is_Type := Item.Kind = Semantics.Type_Relation;
            end if;
         end loop;
         Check.Check
           (Direct_Count = 1 and then Is_Type,
            "cross-kind descendant declarations replace inherited homonyms");
      end;
      declare
         Context : Semantics.Type_Classification_Vectors.Vector;
      begin
         Context.Append
           (Semantics.Type_Classification'
              (Kind => Semantics.Type_Relation,
               Name => To_Unbounded_String ("a"),
               Type_Data =>
                 ((Present => True, Level => 1),
                  To_Unbounded_String ("a")),
               Related_Type => To_Unbounded_String ("b")));
         Context.Append
           (Semantics.Type_Classification'
              (Kind => Semantics.Type_Relation,
               Name => To_Unbounded_String ("b"),
               Type_Data =>
                 ((Present => True, Level => 1),
                  To_Unbounded_String ("b")),
               Related_Type => To_Unbounded_String ("a")));
         Check.Check
           (not Has_Item
              ("procedure P is Items : A; begin for Item of Items loop " &
               "Use (Item); end loop; end P;", Context),
            "cyclic type relations terminate conservatively");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Holder is record Items : Decoder_Array; end record;",
              Identity.Create_Known ("Decoder"), Empty);
         Text : constant String :=
           "procedure P is Value : Holder; begin for Item of Value.Items " &
           "loop Use (Item); end loop; end P;";
      begin
         Check.Check
           (Has_Item (Text, Parent),
            "selected iterators inherit component relations from specs");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Natural_Array is array (Positive range <>) of Natural; " &
              "function Copy return Decoder_Array; " &
              "function Copy (Value : Natural) return Natural_Array;",
              Identity.Create_Known ("Decoder"), Empty);
      begin
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of Copy loop Use (Item); " &
               "end loop; end P;", Parent),
            "inherited callable overloads retain session results");
         Check.Check
           (not Has_Item
              ("procedure P is begin for Item of Copy (1) loop Use (Item); " &
               "end loop; end P;", Parent),
            "callable profiles select matching overload arity");
      end;
   end Run;
end Giflib_Tooling.Session_Iterable_Inheritance_Tests;
