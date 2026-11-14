with Project_Tools.Files;
with Project_Tools.Test_Fixtures;

with Giflib_Tooling.Mutation_Sources;

package body Giflib_Tooling.Mutation_Session_Cases is
   package Files renames Project_Tools.Files;
   package Fixtures renames Project_Tools.Test_Fixtures;
   package Sources renames Giflib_Tooling.Mutation_Sources;
   LF : constant Character := ASCII.LF;

   procedure Replace_Text
     (Path : String; Before : String; After : String)
      renames Sources.Replace_Text;

   procedure Add_Object_Alias (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   Alias : Decoder renames Object;" & LF,
            "   Alias.Current_State := Initialized;" & LF));
   end Add_Object_Alias;

   procedure Add_Local_Helper (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   package Session_Transitions is" & LF &
            "      procedure Reset_Session (Target : in out Decoder);" & LF &
            "   end Session_Transitions;" & LF &
            "   package body Session_Transitions is" & LF &
            "      procedure Reset_Session (Target : in out Decoder) is" & LF &
            "      begin" & LF &
            "         Target.Current_State := Initialized;" & LF &
            "      end Reset_Session;" & LF &
            "   end Session_Transitions;" & LF,
            "   Session_Transitions.Reset_Session (Object);" & LF));
   end Add_Local_Helper;

   procedure Add_Literal_Keyword (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   Marker : constant String := ""end"";" & LF &
            "   pragma Unreferenced (Marker);" & LF,
            "   Object.Current_State := Initialized;" & LF));
   end Add_Literal_Keyword;

   procedure Add_Alternate_Session_Name (Fixture : String) is
      Path : constant String :=
        Files.Join (Fixture, "src/giflib-decoding.adb");
   begin
      Replace_Text
        (Path,
         "package body Giflib.Decoding is" & LF,
         "package body Giflib.Decoding is" & LF &
         "   procedure Alternate_Name_Mutation" & LF &
         "     (Session : in out Decoder)" & LF &
         "   is" & LF &
         "   begin" & LF &
         "      Session.Current_State := Initialized;" & LF &
         "   end Alternate_Name_Mutation;" & LF &
         "   pragma Unreferenced (Alternate_Name_Mutation);" & LF);
   end Add_Alternate_Session_Name;

   procedure Add_Subtype_Session_Name (Fixture : String) is
      Path : constant String :=
        Files.Join (Fixture, "src/giflib-decoding.adb");
   begin
      Replace_Text
        (Path,
         "package body Giflib.Decoding is" & LF,
         "package body Giflib.Decoding is" & LF &
         "   subtype Session_Type is Giflib.Decoding.Decoder;" & LF &
         "   procedure Subtype_Mutation" & LF &
         "     (Session : in out Session_Type)" & LF &
         "   is" & LF &
         "   begin" & LF &
         "      Session.Current_State := Initialized;" & LF &
         "   end Subtype_Mutation;" & LF &
         "   pragma Unreferenced (Subtype_Mutation);" & LF);
   end Add_Subtype_Session_Name;

   procedure Add_Inherited_Subtype (Fixture : String) is
   begin
      Replace_Text
        (Files.Join (Fixture, "src/giflib-decoding.ads"),
         "   subtype Decoder_Resources is " &
         "Internal.Decoder_Storage.Resources;" & LF,
         "   subtype Inherited_Session is Decoder;" & LF &
         "   subtype Decoder_Resources is " &
         "Internal.Decoder_Storage.Resources;" & LF);
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   procedure Mutate (Session : in out Inherited_Session) is" & LF &
            "   begin" & LF &
            "      Session.Current_State := Initialized;" & LF &
            "   end Mutate;" & LF,
            "   Mutate (Object);" & LF));
   end Add_Inherited_Subtype;

   procedure Add_Access_Alias (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   type State_Access is access all Decoder_State;" & LF &
            "   Pointer : constant State_Access := " &
            "Object.Current_State'Unrestricted_Access;" & LF,
            "   Pointer.all := Initialized;" & LF));
   end Add_Access_Alias;

   procedure Add_Access_Session (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   type Decoder_Access is access all Decoder;" & LF &
            "   Pointer : constant Decoder_Access := " &
            "new Decoder (Object.Input);" & LF,
            "   Pointer.Current_State := Initialized;" & LF));
   end Add_Access_Session;

   procedure Add_Indexed_Access_Alias (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   type Warning_Access is access all Errors.Warning;" & LF &
            "   Pointer : constant Warning_Access := " &
            "Object.Warnings (1)'Unrestricted_Access;" & LF &
            "   pragma Unreferenced (Pointer);" & LF,
            ""));
   end Add_Indexed_Access_Alias;

   procedure Add_Address_Alias (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   Location : constant System.Address := Object'Address;" & LF &
            "   pragma Unreferenced (Location);" & LF,
            "", "with System;"));
   end Add_Address_Alias;

   procedure Add_Component_Iterator (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   type Decoder_Access is access all Decoder;" & LF &
            "   type Decoder_Access_Array is array (Positive range <>) of " &
            "Decoder_Access;" & LF &
            "   type Holder is record" & LF &
            "      Items : Decoder_Access_Array (1 .. 1);" & LF &
            "   end record;" & LF &
            "   Value : constant Holder := " &
            "(Items => [1 => new Decoder (Object.Input)]);" & LF,
            "   for Item of Value.Items loop" & LF &
            "      Item.Current_State := Initialized;" & LF &
            "   end loop;" & LF));
   end Add_Component_Iterator;

   procedure Add_Callable_Iterator (Fixture : String) is
   begin
      Fixtures.Write_Text_File
        (Files.Join (Fixture, "src/giflib-decoding-reset.adb"),
         Sources.Reset_Subunit
           ("   type Decoder_Access is access all Decoder;" & LF &
            "   type Decoder_Access_Array is array (Positive range <>) of " &
            "Decoder_Access;" & LF &
            "   Items : constant Decoder_Access_Array := " &
            "[1 => new Decoder (Object.Input)];" & LF &
            "   function Sessions return Decoder_Access_Array is (Items);" & LF,
            "   for Item of Sessions loop" & LF &
            "      Item.Current_State := Initialized;" & LF &
            "   end loop;" & LF));
   end Add_Callable_Iterator;

end Giflib_Tooling.Mutation_Session_Cases;
