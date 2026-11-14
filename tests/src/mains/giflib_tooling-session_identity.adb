with Ada.Strings.Fixed;

with Project_Tools.Ada_Source;

with Giflib_Tooling.Token_Lexemes;
with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Session_Identity is
   use Ada.Strings.Unbounded;
   package Text_Case renames Giflib_Tooling.Text_Case;

   function Valid_Identifier (Name : String) return Boolean is
     (Giflib_Tooling.Token_Lexemes.Valid_Identifier (Name)
      and then not Project_Tools.Ada_Source.Is_Ada_Reserved_Word
        (Text_Case.Lower (Name)));

   function Valid_Selected_Name (Name : String) return Boolean is
      First : Positive := Name'First;
      Dot : Natural;
   begin
      if Name = "" then
         return False;
      end if;
      loop
         Dot := Ada.Strings.Fixed.Index (Name, ".", From => First);
         if Dot = 0 then
            return Valid_Identifier (Name (First .. Name'Last));
         elsif Dot = First then
            return False;
         else
            if not Valid_Identifier (Name (First .. Dot - 1)) then
               return False;
            end if;
            if Dot = Name'Last then
               return False;
            end if;
            First := Dot + 1;
         end if;
      end loop;
   end Valid_Selected_Name;

   function Try_Create
     (Simple_Name : String;
      Qualified_Name : String) return Creation_Result
   is
      Simple : constant String := Text_Case.Lower (Simple_Name);
      Qualified : constant String := Text_Case.Lower (Qualified_Name);
      Dot : constant Natural :=
        Ada.Strings.Fixed.Index (Qualified, ".", Going => Ada.Strings.Backward);
      Terminal : constant String :=
        (if Qualified = "" then Simple
         elsif Dot = 0 then Qualified
         else Qualified (Dot + 1 .. Qualified'Last));
   begin
      if not Valid_Identifier (Simple) then
         return (Success => False, Error => Invalid_Simple_Name);
      elsif Qualified /= "" and then not Valid_Selected_Name (Qualified) then
         return (Success => False, Error => Invalid_Qualified_Name);
      elsif Qualified /= "" and then Terminal /= Simple then
         return (Success => False, Error => Inconsistent_Names);
      else
         return
           (Success => True,
            Item =>
              (Simple => To_Unbounded_String (Simple),
               Qualified => To_Unbounded_String (Qualified)));
      end if;
   end Try_Create;

   function Can_Create
     (Simple_Name : String; Qualified_Name : String := "") return Boolean
   is
      Result : constant Creation_Result :=
        Try_Create (Simple_Name, Qualified_Name);
   begin
      return Succeeded (Result);
   end Can_Create;

   function Succeeded (Result : Creation_Result) return Boolean is
     (Result.Success);

   function Error_Of (Result : Creation_Result) return Identity_Error is
     (Result.Error);

   function Value (Result : Creation_Result) return Target is
     (Result.Item);

   function Create_Known
     (Simple_Name : String; Qualified_Name : String := "") return Target
   is
      Result : constant Creation_Result :=
        Try_Create (Simple_Name, Qualified_Name);
   begin
      return Value (Result);
   end Create_Known;

   function Simple_Name (Item : Target) return String is
     (To_String (Item.Simple));

   function Qualified_Name (Item : Target) return String is
     (To_String (Item.Qualified));

   function Simple_Length (Item : Target) return Natural is
     (Length (Item.Simple));

   function Qualified_Length (Item : Target) return Natural is
     (Length (Item.Qualified));

   function Matches (Item : Target; Name : String) return Boolean is
     (Text_Case.Lower (Name) = Simple_Name (Item)
      or else
        (Qualified_Name (Item) /= ""
         and then Text_Case.Lower (Name) = Qualified_Name (Item)));

   function Qualified_Declaration
     (Unit_Scope : String; Name : String) return String is
     (if Unit_Scope = "" then Text_Case.Lower (Name)
      elsif Name = "" then Text_Case.Lower (Unit_Scope)
      else Text_Case.Lower (Unit_Scope) & "." & Text_Case.Lower (Name));
end Giflib_Tooling.Session_Identity;
