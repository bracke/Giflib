with Ada.Strings.Unbounded;

with Project_Tools.Ada_Source;
with Project_Tools.Files;

with Giflib_Tooling.Architecture_Dependencies;
with Giflib_Tooling.GPR_Analysis;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Names;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Architecture_Interface is
   use Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Dependencies renames Giflib_Tooling.Architecture_Dependencies;
   package Names renames Giflib_Tooling.Source_Names;
   package GPR renames Giflib_Tooling.GPR_Analysis;
   package Text_Case renames Giflib_Tooling.Text_Case;
   package Snapshots renames Giflib_Tooling.Repository_Snapshots;

   procedure Check_Library_Interface
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
      Root : constant String := Snapshots.Root (Repository);
      Actual : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
      procedure Load_Interface (Text : String) is
      begin
         Giflib_Tooling.Work_Budgets.Charge_Scan (Budget, Text'Length);
         Actual := GPR.Attribute_Strings (Text, "Library_Interface");
      end Load_Interface;
      type Dependency_Policy is
        (Public_Leaf, Decoder_Facade, Encoder_Facade, Quantization_Facade,
         Internal_Unit);
      type Interface_Entry is record
         Name : Unbounded_String;
         Policy : Dependency_Policy;
      end record;
      function Make_Entry
        (Name : String; Policy : Dependency_Policy := Public_Leaf)
         return Interface_Entry is
        ((To_Unbounded_String (Name), Policy));
      Manifest : constant array (Positive range <>) of Interface_Entry :=
        [Make_Entry ("Giflib"),
         Make_Entry ("Giflib.Animations"),
         Make_Entry ("Giflib.Capabilities"),
         Make_Entry ("Giflib.Cleanup"),
         Make_Entry ("Giflib.Decoding", Decoder_Facade),
         Make_Entry ("Giflib.Encoding", Encoder_Facade),
         Make_Entry ("Giflib.Errors"),
         Make_Entry ("Giflib.Frames"),
         Make_Entry ("Giflib.Images"),
         Make_Entry ("Giflib.Limits"),
         Make_Entry ("Giflib.Metadata"),
         Make_Entry ("Giflib.Optimization"),
         Make_Entry ("Giflib.Palettes"),
         Make_Entry ("Giflib.Quantization", Quantization_Facade),
         Make_Entry ("Giflib.Results"),
         Make_Entry ("Giflib.Streams"),
         Make_Entry ("Giflib.Version"),
         Make_Entry ("Giflib.Internal", Internal_Unit),
         Make_Entry ("Giflib.Internal.Blocks", Internal_Unit),
         Make_Entry ("Giflib.Internal.Borrow_Guards", Internal_Unit),
         Make_Entry ("Giflib.Internal.Budget_Arithmetic", Internal_Unit),
         Make_Entry ("Giflib.Internal.Cleanup", Internal_Unit),
         Make_Entry ("Giflib.Internal.Decoder_Storage", Internal_Unit),
         Make_Entry ("Giflib.Internal.Encoder_Storage", Internal_Unit),
         Make_Entry ("Giflib.Internal.Interlacing", Internal_Unit),
         Make_Entry ("Giflib.Internal.LZW", Internal_Unit),
         Make_Entry ("Giflib.Internal.LZW_Arithmetic", Internal_Unit),
         Make_Entry ("Giflib.Internal.LZW_Decoder_Dictionary", Internal_Unit),
         Make_Entry ("Giflib.Internal.LZW_Encoding", Internal_Unit),
         Make_Entry ("Giflib.Internal.LZW_Encoder_Dictionary", Internal_Unit),
         Make_Entry ("Giflib.Internal.Metadata_Store", Internal_Unit),
         Make_Entry ("Giflib.Internal.Owned_Arrays", Internal_Unit),
         Make_Entry ("Giflib.Internal.Owned_Buffers", Internal_Unit),
         Make_Entry ("Giflib.Internal.Owned_Objects", Internal_Unit),
         Make_Entry ("Giflib.Internal.Owned_Vectors", Internal_Unit),
         Make_Entry ("Giflib.Internal.Ownership", Internal_Unit),
         Make_Entry ("Giflib.Internal.Ownership_Arithmetic", Internal_Unit),
         Make_Entry
           ("Giflib.Internal.Quantization_Buffer_Arithmetic", Internal_Unit),
         Make_Entry ("Giflib.Internal.Quantization_Dithering", Internal_Unit),
         Make_Entry ("Giflib.Internal.Quantization_Histograms", Internal_Unit),
         Make_Entry ("Giflib.Internal.Quantization_Palette", Internal_Unit),
         Make_Entry ("Giflib.Internal.Quantization_Storage", Internal_Unit),
         Make_Entry ("Giflib.Internal.Work_Budgets", Internal_Unit)];
      Empty : constant Project_Tools.Ada_Source.String_List := [1 .. 0 => <>];
      Decoding_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Decoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Ownership")];
      Encoding_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Encoder_Storage"),
         To_Unbounded_String ("Giflib.Internal.Ownership")];
      Quantization_Allowed : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Giflib.Internal.Ownership"),
         To_Unbounded_String ("Giflib.Internal.Quantization_Storage")];

      procedure Check_Public_Spec
        (Unit_Name : String;
         Allowed : Project_Tools.Ada_Source.String_List) is
      begin
         Dependencies.Require_Only_Allowed_With_Clauses
           (Cached_Sources,
            Files.Join
              (Files.Join
                 (Root, "src"), Names.Specification_File_Name (Unit_Name)),
            "Giflib.Internal", Allowed, Budget);
      end Check_Public_Spec;

      function Has_Interface_Unit (Unit_Name : String) return Boolean is
         Target : constant String := Text_Case.Lower (Unit_Name);
      begin
         for Name of Actual loop
            if Text_Case.Lower (To_String (Name)) = Target then
               return True;
            end if;
         end loop;
         return False;
      end Has_Interface_Unit;
   begin
      Snapshots.Inspect_Text
        (Repository, Files.Join (Root, "giflib.gpr"), Load_Interface'Access);
      if Natural (Actual.Length) /= Manifest'Length then
         Fail ("library interface unit inventory changed without review");
      end if;
      for Item of Manifest loop
         if not Has_Interface_Unit (To_String (Item.Name)) then
            Fail ("library interface unit inventory changed without review");
         end if;
      end loop;
      for Item of Manifest loop
         declare
            Unit_Name : constant String := To_String (Item.Name);
         begin
            case Item.Policy is
               when Public_Leaf => Check_Public_Spec (Unit_Name, Empty);
               when Decoder_Facade =>
                  Check_Public_Spec (Unit_Name, Decoding_Allowed);
               when Encoder_Facade =>
                  Check_Public_Spec (Unit_Name, Encoding_Allowed);
               when Quantization_Facade =>
                  Check_Public_Spec (Unit_Name, Quantization_Allowed);
               when Internal_Unit => null;
            end case;
         end;
      end loop;
   end Check_Library_Interface;

   procedure Validate
     (Repository : Snapshots.Snapshot;
      Cached_Sources : Giflib_Tooling.Repository_Source_Cache.Cache;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget) is
   begin
      Check_Library_Interface (Repository, Cached_Sources, Budget);
   end Validate;
end Giflib_Tooling.Architecture_Interface;
