with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.Transition_Policy_Index is
   type Index is private;

   function Is_Trusted_Qualifier
     (Object : Index; Name : String) return Boolean;
   function Is_Allowed_Call
     (Object : Index; Callee : String; Unit_Name : String) return Boolean;
   function Is_Global_Allowed_Call
     (Object : Index; Callee : String) return Boolean;
   type Family_Match (Found : Boolean := False) is record
      case Found is
         when True =>
            Prefix : Ada.Strings.Unbounded.Unbounded_String;
         when False =>
            null;
      end case;
   end record;
   function Allowed_Family
     (Object : Index; Callee : String; Unit_Name : String)
      return Family_Match;
   function Is_Reviewed_Alias
     (Object : Index;
      Unit_Name : String;
      Alias_Name : String;
      Target : String) return Boolean;

private
   use Ada.Strings.Unbounded;

   type Family_Call_Key is record
      Unit_Name : Unbounded_String;
      Callee : Unbounded_String;
   end record;
   type Alias_Key is record
      Unit_Name : Unbounded_String;
      Alias_Name : Unbounded_String;
   end record;

   function Hash (Item : Family_Call_Key) return Ada.Containers.Hash_Type;
   function Hash (Item : Alias_Key) return Ada.Containers.Hash_Type;
   function Family_Key
     (Unit_Name : String; Callee : String) return Family_Call_Key;
   function Reviewed_Alias_Key
     (Unit_Name : String; Alias_Name : String) return Alias_Key;

   package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type => String,
      Hash => Ada.Strings.Hash,
      Equivalent_Elements => "=");
   package Family_Call_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type => Family_Call_Key,
      Hash => Hash,
      Equivalent_Elements => "=");
   package Alias_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => Alias_Key,
      Element_Type => Unbounded_String,
      Hash => Hash,
      Equivalent_Keys => "=");
   type Index is record
      Session_Prefix : Unbounded_String;
      Global_Calls : Name_Sets.Set;
      Family_Prefixes : Name_Sets.Set;
      Family_Calls : Family_Call_Sets.Set;
      Reviewed_Aliases : Alias_Maps.Map;
      Trusted_Qualifiers : Name_Sets.Set;
   end record;
end Giflib_Tooling.Transition_Policy_Index;
