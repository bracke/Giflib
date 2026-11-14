with Ada.Strings.Unbounded;

with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Query_Testing;
with Giflib_Tooling.Session_Iterable_Test_Support;
with Giflib_Tooling.Session_Types;

package body Giflib_Tooling.Session_Iterable_Visibility_Tests is
   use Ada.Strings.Unbounded;
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
             ("package Root is " &
              "type Root_Decoder_Array is array (Positive range <>) " &
              "of Decoder; function Root_Sessions return Root_Decoder_Array; " &
              "package Nested is " &
              "type Decoder_Array is array (Positive range <>) of Decoder; " &
              "function Sessions return Decoder_Array; end Nested; end Root;",
              Identity.Create_Known ("Decoder"), Empty, "root");
      begin
         Check.Check
           (not Has_Item
              ("procedure P is begin for Item of Sessions loop Use (Item); " &
               "end loop; end P;", Parent),
            "nested package declarations do not escape their scope");
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of Root_Sessions loop " &
               "Use (Item); end loop; end P;", Parent),
            "root package declarations define the exported context");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Parent : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "type Natural_Array is array (Positive range <>) of Natural; " &
              "function Copy (Value : First.T) return Decoder_Array; " &
              "function Copy (Value : Second.T) return Natural_Array; " &
              "function Class_Copy (Value : First.T) return Decoder_Array; " &
              "function Class_Copy (Value : First.T'Class) " &
              "return Natural_Array;", Identity.Create_Known ("Decoder"), Empty);
      begin
         Check.Check
           (not Has_Item
              ("procedure P is Value : Second.T; begin " &
               "for Item of Copy (Value) loop Use (Item); end loop; end P;",
               Parent),
            "selected formal type names distinguish overloads");
         Check.Check
           (Has_Item
              ("procedure P is Value : First.T; begin " &
               "for Item of Copy (Value) loop Use (Item); end loop; end P;",
               Parent),
            "selected formal type names retain matching results");
         Check.Check
           (not Has_Item
              ("procedure P is Value : First.T'Class; begin " &
               "for Item of Class_Copy (Value) loop Use (Item); end loop; " &
               "end P;", Parent),
            "class-wide formal types retain their full identity");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         Context : Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Natural_Array is array (Positive range <>) of Natural; " &
              "function Copy (Value : Natural_Array) return Natural_Array;",
              Identity.Create_Known ("Decoder"), Empty);
         Unknown_Profile : Semantics.Callable_Profile;
      begin
         Unknown_Profile.Minimum_Arguments := 1;
         Unknown_Profile.Maximum_Arguments := 1;
         Unknown_Profile.Formal_Types.Append (Null_Unbounded_String);
         Context.Append
           (Semantics.Type_Classification'
              (Kind => Semantics.Callable_Relation,
               Name => To_Unbounded_String ("copy"),
               Callable_Data =>
                 ((Present => True, Level => 1),
                  To_Unbounded_String ("decoder_array")),
               Scope_Name => Null_Unbounded_String,
               Profile => Unknown_Profile));
         Check.Check
           (not Has_Item
              ("procedure P is Values : Natural_Array; begin " &
               "for Item of Copy (Values) loop Use (Item); end loop; end P;",
               Context),
            "exact formal types outrank unknown overloads");
      end;
      declare
         Empty : Semantics.Type_Classification_Vectors.Vector;
         First_Context : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Decoder_Array is array (Positive range <>) of Decoder; " &
              "function Sessions return Decoder_Array;",
              Identity.Create_Known ("Decoder"), Empty, "alpha.provider");
         Context : constant Semantics.Type_Classification_Vectors.Vector :=
           Queries.Package_Type_Context
             ("type Natural_Array is array (Positive range <>) of Natural; " &
              "function Sessions return Natural_Array;",
              Identity.Create_Known ("Decoder"), First_Context, "beta.provider");
      begin
         Check.Check
           (not Has_Item
              ("procedure P is begin for Item of Provider.Sessions loop " &
               "Use (Item); end loop; end P;", Context),
            "ambiguous short qualifiers do not select a package");
         Check.Check
           (Has_Item
              ("procedure P is begin for Item of Alpha.Provider.Sessions loop " &
               "Use (Item); end loop; end P;", Context),
            "fully qualified callable identities remain selectable");
      end;
   end Run;
end Giflib_Tooling.Session_Iterable_Visibility_Tests;
