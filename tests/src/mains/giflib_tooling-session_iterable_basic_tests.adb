with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Iterable_Test_Support;
with Giflib_Tooling.Session_Types;

package body Giflib_Tooling.Session_Iterable_Basic_Tests is
   use Giflib_Tooling.Session_Iterable_Test_Support;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Semantics renames Giflib_Tooling.Session_Types;
   use type Semantics.Session_Depth;

   procedure Run is
      Component : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; Items : Decoder_Array; begin for Item of Items loop " &
        "Item.Current_State := Initialized; end loop; end P;";
      Nested : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Decoder_Matrix is array (Positive range <>) " &
        "of Decoder_Array; Items : Decoder_Matrix; begin for Row of Items " &
        "loop for Item of Row loop Item.Current_State := Initialized; " &
        "end loop; end loop; end P;";
      Computed : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; Items : Decoder_Array; begin for Item of " &
        "(if Flag then Items else Items) loop " &
        "Item.Current_State := Initialized; end loop; end P;";
      Case_Computed : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; Items : Decoder_Array; begin for Item of " &
        "(case Flag is when True => Items, when False => Items) loop " &
        "Use (Item); end loop; end P;";
      Selected : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Holder is record Items : Decoder_Array; " &
        "end record; Value : Holder; begin for Item of Value.Items loop " &
        "Item.Current_State := Initialized; end loop; end P;";
      Discriminated_Selected : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Holder (First : Natural; Second : Natural) is " &
        "record Items : Decoder_Array; end record; Value : Holder (1, 2); " &
        "begin for Item of Value.Items loop Use (Item); end loop; end P;";
      Collision : constant String :=
        "procedure P is type Natural_Array is array (Positive range <>) " &
        "of Natural; type Plain_Holder is record Items : Natural_Array; " &
        "end record; type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Session_Holder is record Items : Decoder_Array; " &
        "end record; Value : Plain_Holder; begin for Item of Value.Items " &
        "loop Use (Item); end loop; end P;";
      Unrelated : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Natural_Array is array (Positive range <>) " &
        "of Natural; Sessions : Decoder_Array; Values : Natural_Array; " &
        "begin for Item of Values (Sessions'First .. Sessions'Last) loop " &
        "Use (Item); end loop; end P;";
      Natural_Result : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; type Natural_Array is array (Positive range <>) " &
        "of Natural; Sessions : Decoder_Array; Values : Natural_Array; " &
        "function Copy (Input : Decoder_Array) return Natural_Array is " &
        "(Values); begin for Item of Copy (Sessions) loop Use (Item); " &
        "end loop; end P;";
      Session_Result : constant String :=
        "procedure P is type Decoder_Array is array (Positive range <>) " &
        "of Decoder; Items : Decoder_Array; function Copy " &
        "(Input : Decoder_Array) return Decoder_Array is (Input); " &
        "begin for Item of Copy (Items) loop Use (Item); end loop; end P;";
      Ordinary : constant String :=
        "procedure P is type Natural_Array is array (Positive range <>) " &
        "of Natural; Values : Natural_Array; begin for Item of Values loop " &
        "Use (Item); end loop; end P;";
   begin
      Check.Check
        (Semantics.Nested (Semantics.Direct_Session) =
           (Present => True, Level => 1)
         and then
           Semantics.Element (Semantics.Nested (Semantics.Direct_Session)) =
             Semantics.Direct_Session
         and then
           Semantics.Element (Semantics.No_Session_Depth) =
             Semantics.No_Session_Depth,
         "session nesting represents absence without a numeric sentinel");
      Expect_Item (Component, "Item.Current_State", True,
                   "component iterators are session-bearing");
      Expect_Item (Nested, "Item.Current_State", True,
                   "nested iterators preserve recursive session depth");
      Expect_Item (Computed, "Item.Current_State", True,
                   "computed iterators preserve session depth");
      Expect_Item (Case_Computed, "Use (Item)", True,
                   "case-expression iterators preserve session depth");
      Expect_Item (Selected, "Item.Current_State", True,
                   "selected iterators preserve session depth");
      Expect_Item (Discriminated_Selected, "Use (Item)", True,
                   "discriminated record components preserve session depth");
      Expect_Item (Collision, "Use (Item)", False,
                   "component relations are owner-qualified");
      Expect_Item (Unrelated, "Use (Item)", False,
                   "unrelated expression identifiers are ignored");
      Expect_Item (Natural_Result, "Use (Item)", False,
                   "function arguments do not define result types");
      Expect_Item (Session_Result, "Use (Item)", True,
                   "function result types define iterator types");
      Expect_Item (Ordinary, "Use (Item)", False,
                   "ordinary iterators are not sessions");
   end Run;
end Giflib_Tooling.Session_Iterable_Basic_Tests;
