with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Query_Testing;

package body Giflib_Tooling.Session_Scope_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Queries renames Giflib_Tooling.Session_Query_Testing;

   procedure Expect
     (Text : String; Fragment : String; Name : String;
      Present : Boolean; Message : String)
   is
      Names : constant Giflib_Tooling.Name_Collections.Name_Vectors.Vector :=
        Queries.Identifiers_At
          (Text,
           Identity.Create_Known ("Decoder", "giflib.decoding.decoder"),
           Check.Position_After (Text, Fragment));
   begin
      Check.Check (Giflib_Tooling.Name_Collections.Contains (Names, Name) = Present, Message);
   end Expect;

   procedure Run is
      Scoped_Text : constant String :=
        "procedure First (Object : in out Decoder) is begin null; end First; " &
        "procedure Second (Object : in out Natural) is begin Object := 1; " &
        "end Second;";
      Alias_Text : constant String :=
        "subtype Session is Giflib.Decoding.Decoder; " &
        "procedure P (Object : in out Session) is begin " &
        "Object.Current_State := Initialized; end P;";
      Access_Text : constant String :=
        "type Decoder_Access is access all Decoder; " &
        "procedure P (Pointer : Decoder_Access) is begin " &
        "Pointer.Current_State := Initialized; end P;";
      Alias_Shadow_Text : constant String :=
        "procedure P (Object : in out Decoder) is subtype Session is Decoder; " &
        "procedure Inner is subtype Session is Natural; Value : Session; " &
        "begin Value := 1; end Inner; begin null; end P;";
      Block_Text : constant String :=
        "procedure P (Object : in out Decoder) is begin declare " &
        "Object : Natural; begin Object := 1; end; end P;";
      Loop_Text : constant String :=
        "procedure P (Object : in out Decoder) is begin " &
        "for Object in 1 .. 2 loop Use (Object); end loop; end P;";
      Handler_Text : constant String :=
        "procedure P (Object : in out Decoder) is begin null; exception " &
        "when Object : others => Use (Object); end P;";
      Nested_Handler_Text : constant String :=
        "procedure P (Item : in out Decoder) is begin null; exception " &
        "when Item : others => if Flag then null; end if; Use (Item); end P;";
      Return_Text : constant String :=
        "function P return Decoder is begin return Object : Decoder do " &
        "Object.Current_State := Initialized; end return; end P;";
      Type_Profile_Text : constant String :=
        "procedure P (Object : in out Decoder) is type Sample " &
        "(First : Natural; Object : Natural) is null record; begin " &
        "Use (Object); end P;";
      Case_Expression_Text : constant String :=
        "procedure P is First : Natural := (case Flag is when True => 1, " &
        "when False => 2); Object : Decoder; Second : Natural := " &
        "(case Flag is when True => 3, when False => 4); begin " &
        "Use (Object); end P;";
      Literal_Keyword_Text : constant String :=
        "procedure P (Object : in out Decoder) is begin Sink (""end""); " &
        "Object.Current_State := Initialized; end P;";
      Cross_Kind_Shadow_Text : constant String :=
        "procedure P (Object : in out Decoder) is begin declare package " &
        "Object is Current_State : Natural; end Object; begin " &
        "Object.Current_State := 1; end; end P;";
      Qualified_Shadow_Text : constant String :=
        "procedure P is type Decoder is null record; " &
        "Object : Giflib.Decoding.Decoder; begin Use (Object); end P;";
      Unrelated_Selected_Text : constant String :=
        "package Other is type Decoder is null record; end Other; " &
        "procedure P is Object : Other.Decoder; begin Use (Object); end P;";
      Aliased_Selected_Text : constant String :=
        "package Codec renames Giflib.Decoding; " &
        "procedure P is Object : Codec.Decoder; begin Use (Object); end P;";
   begin
      Check.Check
        (Giflib_Tooling.Name_Collections.Contains
           (Queries.Identifiers
              ("procedure P (First, Session : in out Decoder) is",
               Identity.Create_Known ("Decoder")),
            "session"),
         "session identifier derivation");
      Check.Check
        (Giflib_Tooling.Name_Collections.Contains
           (Queries.Identifiers
              ("procedure P (First, Session : in out Decoder) is",
               Identity.Create_Known ("Decoder")),
            "first"),
         "grouped session identifier derivation");
      Expect (Alias_Text, "Object.Current_State", "object", True,
              "subtype-aliased session identifier derivation");
      Expect (Access_Text, "Pointer.Current_State", "pointer", True,
              "access-to-session identifier derivation");
      Expect (Alias_Shadow_Text, "Value := 1", "value", False,
              "subtype aliases are lexically scoped");
      Expect (Scoped_Text, "Object := 1", "object", False,
              "session identifiers are lexically scoped");
      Expect (Block_Text, "Object := 1", "object", False,
              "session identifiers respect declare blocks");
      Expect (Loop_Text, "Use (Object)", "object", False,
              "session identifiers respect loop parameters");
      Expect (Handler_Text, "Use (Object)", "object", False,
              "session identifiers respect exception choices");
      Expect (Nested_Handler_Text, "Use (Item)", "item", False,
              "nested control endings preserve exception-choice bindings");
      Expect (Return_Text, "Object.Current_State", "object", True,
              "session identifiers include extended return objects");
      Expect (Type_Profile_Text, "Use (Object)", "object", True,
              "type discriminants do not leak into enclosing scopes");
      Expect (Case_Expression_Text, "Use (Object)", "object", True,
              "case expressions do not create handler scopes");
      Expect (Literal_Keyword_Text, "Object.Current_State", "object", True,
              "string literal keywords do not change lexical scope");
      Expect (Cross_Kind_Shadow_Text, "Object.Current_State", "object", False,
              "cross-kind declarations hide outer session objects");
      Expect
        (Qualified_Shadow_Text, "Use (Object)", "object", True,
         "qualified session types survive terminal-name shadowing");
      Expect
        (Unrelated_Selected_Text, "Use (Object)", "object", False,
         "unrelated selected types do not inherit session identity");
      Expect
        (Aliased_Selected_Text, "Use (Object)", "object", True,
         "package aliases preserve selected session identity");
      Check.Check
        (not Giflib_Tooling.Name_Collections.Contains
           (Queries.Identifiers_At
              ("procedure First (Object : in out Decoder) is begin null; " &
               "end; procedure Second is begin Use (Object); end Second;",
               Identity.Create_Known ("Decoder"), 200),
            "object"),
         "unnamed endings close session-analysis scopes");
      declare
         Cursor_Text : constant String :=
           "procedure P (Object : Decoder) is begin Sink (""abc""); " &
           "Use (Object); end P;";
      begin
         Check.Check
           (Giflib_Tooling.Name_Collections.Contains
              (Queries.Identifiers_At
                 (Cursor_Text, Identity.Create_Known ("Decoder"),
                  Check.Position_After (Cursor_Text, """a")),
               "object"),
            "cursor queries analyze complete string tokens");
      end;
      declare
         Cursor_Text : constant String :=
           "procedure P is Future : Decoder; begin Use (Future); end P;";
      begin
         Check.Check
           (not Giflib_Tooling.Name_Collections.Contains
              (Queries.Identifiers_At
                 (Cursor_Text, Identity.Create_Known ("Decoder"),
                  Check.Position_After (Cursor_Text, ":")),
               "future"),
            "cursor queries cannot inspect future declaration tokens");
      end;
      declare
         Cursor_Text : constant String :=
           "procedure P (Object : Decoder) is begin Use (Object); " &
           "Sink (""unterminated";
      begin
         Check.Check
           (Giflib_Tooling.Name_Collections.Contains
              (Queries.Identifiers_At
                 (Cursor_Text, Identity.Create_Known ("Decoder"),
                  Check.Position_After (Cursor_Text, "Use (Object);")),
               "object"),
            "cursor queries ignore malformed text after the snapshot");
      end;
      declare
         Base : constant String :=
           "procedure P (Object : Decoder) is begin null; end P; " &
           "Use (Object);";
         Rebased : constant String (5 .. Base'Length + 4) := Base;
         Position : constant Natural := Check.Position_After (Base, "end P;");
      begin
         Check.Check
           (not Giflib_Tooling.Name_Collections.Contains
              (Queries.Identifiers_At
                 (Rebased, Identity.Create_Known ("Decoder"), Position),
               "object"),
            "cursor positions are relative for non-1-based source values");
      end;
   end Run;
end Giflib_Tooling.Session_Scope_Tests;
