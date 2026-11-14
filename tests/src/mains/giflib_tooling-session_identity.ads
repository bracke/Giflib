with Ada.Strings.Unbounded;

private package Giflib_Tooling.Session_Identity is
   type Target is private;
   type Identity_Error is
     (No_Identity_Error, Invalid_Simple_Name, Invalid_Qualified_Name,
      Inconsistent_Names);

   function Can_Create
     (Simple_Name : String; Qualified_Name : String := "") return Boolean;
   function Create_Known
     (Simple_Name : String; Qualified_Name : String := "") return Target
     with Pre => Can_Create (Simple_Name, Qualified_Name);
   type Creation_Result (<>) is private;
   function Try_Create
     (Simple_Name : String;
      Qualified_Name : String) return Creation_Result;
   function Succeeded (Result : Creation_Result) return Boolean;
   function Error_Of (Result : Creation_Result) return Identity_Error
     with Pre => not Succeeded (Result);
   function Value (Result : Creation_Result) return Target
     with Pre => Succeeded (Result);
   function Simple_Name (Item : Target) return String;
   function Qualified_Name (Item : Target) return String;
   function Simple_Length (Item : Target) return Natural;
   function Qualified_Length (Item : Target) return Natural;
   function Matches (Item : Target; Name : String) return Boolean;
   function Qualified_Declaration
     (Unit_Scope : String; Name : String) return String;
private
   type Target is record
      Simple : Ada.Strings.Unbounded.Unbounded_String;
      Qualified : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   type Creation_Result (Success : Boolean) is record
      case Success is
         when True =>
            Item : Target;
         when False =>
            Error : Identity_Error;
      end case;
   end record;
end Giflib_Tooling.Session_Identity;
